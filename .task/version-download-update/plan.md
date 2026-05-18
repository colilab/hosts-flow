# Plan: Manual & Automatic Update Check (Sparkle)

**Date:** 2026-05-18
**Type:** feature
**Ref:** —

## Original prompt
> Vorrei anche che ci fosse un pulsante che permetta manualmente di controllare se ci sono nuovi aggiornamenti disponibili. Come sviluppo ulteriore, voglio inserire una feature di aggiornamento automatico dell'applicazione ogni volta che c'è una nuova versione disponibile.

## Summary
Integrate Sparkle 2 to give Host Flow a "Check for Updates…" button (Settings → About and Menu Bar popover) plus weekly automatic background checks with user prompt before download/install. Updates are distributed via GitHub Releases on `colilab/hosts-flow`; an appcast feed is auto-published to GitHub Pages by a tag-triggered GitHub Action. Sparkle uses its own dedicated EdDSA keypair (kept off-tree, alongside the existing manifest key) and replaces the `.app` atomically — preserving the daemon manifest-hash invariant (`docs/release.md`), since the new bundle ships its own valid manifest produced by `build-release.sh`.

## Steps

### 1 — Sparkle dependency & project wiring
1. [ ] Add Sparkle 2 SwiftPM dependency in `HostFlow/project.yml` (package `https://github.com/sparkle-project/Sparkle`, version `from: 2.6.0`) and link `Sparkle` to the `HostFlow` target — `HostFlow/project.yml`.
2. [ ] Run `xcodegen generate` (inside `HostFlow/`) to regenerate `HostFlow.xcodeproj/project.pbxproj`.

### 2 — Sparkle EdDSA key
3. [ ] Add `Scripts/make-sparkle-keys.sh` — wraps Sparkle's `generate_keys` tool (vendored via SwiftPM build product `Sparkle/bin/generate_keys`), printing the `SUPublicEDKey` value and asking the developer to move the private key to `~/Documents/keys-vault/hostflow-sparkle-private.key` (chmod 600). Mirrors the contract of `Scripts/make-keys.sh` — `Scripts/make-sparkle-keys.sh`.
4. [ ] Manually run the script once, capture the public key string, and embed it as `SUPublicEDKey` in `Info.plist` (next step). Private key never touches the repo; `.gitignore` already covers it.

### 3 — Info.plist Sparkle configuration
5. [ ] Add Sparkle keys to `HostFlow/Resources/Info.plist`:
   - `SUFeedURL` = `https://colilab.github.io/hosts-flow/appcast.xml`
   - `SUPublicEDKey` = `<from step 4>`
   - `SUEnableAutomaticChecks` = `YES` (default ON, user can flip in Settings)
   - `SUScheduledCheckInterval` = `604800` (weekly)
   - `SUAutomaticallyUpdate` = `NO` (prompt user before download/install)
   - `SUEnableInstallerLauncherService` = `NO` (app is not sandboxed; no XPC needed)

### 4 — UpdaterStore
6. [ ] Create `HostFlow/Stores/UpdaterStore.swift` — `@Observable` wrapper around `SPUStandardUpdaterController` exposing:
   - `checkForUpdates()` → calls `updater.checkForUpdates()`
   - `var automaticallyChecksForUpdates: Bool` (two-way bound, persists via Sparkle)
   - `var lastUpdateCheckDate: Date?`
   - `var canCheckForUpdates: Bool` (mirrors Sparkle's published property for disabling the button while a check is in-flight)
   Initializer: `SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)`.
7. [ ] Inject `UpdaterStore` as `.environment(UpdaterStore())` in `HostFlow/App/HostFlowApp.swift` next to the other stores.

### 5 — Settings UI (About section)
8. [ ] In `HostFlow/Views/Settings/SettingsView.swift`:
   - Inject `@Environment(UpdaterStore.self) private var updater`.
   - In the About section, after `LabeledContent("settings.about.version", …)`:
     - Add `Toggle("settings.about.auto_check", isOn: $updater.automaticallyChecksForUpdates)`.
     - Add a `Button("settings.about.check_updates") { updater.checkForUpdates() }.disabled(!updater.canCheckForUpdates)`.
     - Below, a caption `Text` showing "Last checked: <relative date>" if `lastUpdateCheckDate` is non-nil.

### 6 — Menu Bar entry
9. [ ] In `HostFlow/Views/MenuBar/MenuBarView.swift` (locate exact filename — likely `MenuBarView.swift` under `HostFlow/Views/MenuBar/`):
   - Inject `UpdaterStore` from environment.
   - Add a `Button("menu.check_updates") { updater.checkForUpdates() }` near the "Settings…" / "Quit" items, separated by a `Divider`.

### 7 — Localization
10. [ ] Add keys to all `Localizable.xcstrings` (or `.strings`) catalogs in the project:
    - `settings.about.check_updates` — "Check for Updates…" / "Verifica aggiornamenti…"
    - `settings.about.auto_check` — "Automatically check for updates" / "Controlla automaticamente"
    - `settings.about.last_checked` — "Last checked: %@" / "Ultimo controllo: %@"
    - `menu.check_updates` — "Check for Updates…" / "Verifica aggiornamenti…"
    Find existing string catalog via `find HostFlow -name "*.xcstrings"`.

### 8 — Release pipeline: DMG + Sparkle signature
11. [ ] Extend `Scripts/build-release.sh`:
    - After the existing manifest-signing step, package the `.app` into `dist/HostFlow-<version>.dmg` via `hdiutil create -volname "Host Flow" -srcfolder "$APP" -ov -format UDZO`.
    - Require new env var `HOSTFLOW_SPARKLE_PRIVATE_KEY` pointing at the Sparkle Ed25519 key file (fail-fast like the existing `HOSTFLOW_PRIVATE_KEY` check).
    - Invoke Sparkle's `sign_update` on the DMG (binary built by SwiftPM and resolved at `~/Library/Developer/Xcode/DerivedData/<…>/Sparkle/bin/sign_update`, or vendored). Capture the resulting `sparkle:edSignature` and `length` attributes.
    - Emit `dist/appcast-entry.json` with `{version, shortVersion, dmgFilename, length, edSignature, minimumSystemVersion}` — consumed by the GitHub workflow.
    - Print the DMG path and entry file path at the end.
    Critical: DMG packaging must happen **after** `sign-manifest.sh` and must not re-codesign the `.app` (the invariant in `docs/release.md` still applies — `hdiutil` does not re-sign).
12. [ ] Update `docs/release.md` §3 with the new env var, DMG output, and a sub-section §5.3 on Sparkle distribution & key rotation.

### 9 — GitHub release workflow & appcast publishing
13. [ ] Add `.github/workflows/release.yml`:
    - Trigger: `on: push: tags: ['[0-9]+.[0-9]+.[0-9]+']` (stable tags only — no `-pre`, `-rc`, `-fix` matching).
    - Job `publish-release`:
      - Checkout main with the tag.
      - Download the DMG + `appcast-entry.json` from the run that produced them. Since the dev builds locally, the dev pushes them by creating a draft GitHub Release with the DMG attached before pushing the tag — workflow then uses `gh release edit` to publish.
      - Alternative (preferred): the workflow expects the dev to run `gh release create <tag> --draft dist/HostFlow-<tag>.dmg dist/appcast-entry.json --notes-file <changelog excerpt>` and only handles the publish + appcast update.
    - Job `update-appcast`:
      - Checkout `gh-pages` branch (create if missing).
      - Append a new `<item>` to `appcast.xml` using values from `appcast-entry.json`, with release-body HTML from `gh release view <tag> --json body --jq .body | <markdown-to-html>` (use `pandoc` or `marked` action).
      - Commit & push back to `gh-pages`.
    - Document the exact dev flow in `docs/release.md` (run `build-release.sh` → run `Scripts/publish.sh` which wraps `gh release create … --draft` → push tag via `Scripts/release.sh` → workflow takes over).
14. [ ] Add `Scripts/publish.sh` — thin wrapper that takes `dist/HostFlow-<version>.dmg` + `dist/appcast-entry.json` and runs `gh release create <version> --draft --title … --notes-file … HostFlow-<version>.dmg appcast-entry.json`. Reads version from `project.yml` to avoid argument mistakes.

### 10 — GitHub Pages bootstrap
15. [ ] Create the initial `gh-pages` branch (orphan) with a placeholder `appcast.xml`:
    ```xml
    <?xml version="1.0" standalone="yes"?>
    <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
        <title>Host Flow Updates</title>
        <link>https://colilab.github.io/hosts-flow/appcast.xml</link>
        <description>Stable update feed for Host Flow.</description>
      </channel>
    </rss>
    ```
    Enable GitHub Pages (Settings → Pages → Source: `gh-pages` / root) — done in the GitHub UI, document the step in `docs/release.md`.

### 11 — README & docs
16. [ ] Add "Updates" section to `README.md` explaining manual check, automatic check toggle, where updates come from, and that pre-release channels are not auto-proposed.
17. [ ] In `docs/release.md`, add §9 "Sparkle update channel" documenting: key generation/rotation flow, appcast URL, workflow architecture, and the invariant that DMG packaging must not re-sign the bundle.

### 12 — Validation
18. [ ] Local smoke test: bump version locally to a fake `0.0.1-test`, run `build-release.sh` + `publish.sh` against a private throwaway repo (or a `--prerelease`-flagged release), confirm Sparkle in the previous build detects and installs the new one, and confirm the post-update app still passes the daemon manifest verification (`/etc/hosts` write works after auto-update).
19. [ ] If validation succeeds, revert the throwaway version bump.

## Out of scope
- Pre-release/rc channels in Sparkle (stable only — `develop`/`quality` builds never surface as updates).
- Delta updates (Sparkle's `bsdiff` patches) — full DMG download every time.
- In-app changelog/release-notes UI separate from Sparkle's native dialog.
- Notifying about updates from the menu bar icon (badge/dot) — only the explicit "Check for Updates…" item.
- Reusing the existing manifest Ed25519 key for Sparkle — explicitly a separate key.
- Background download without user prompt (`SUAutomaticallyUpdate` stays `NO`).

## Open questions
- None — all decisions made during grilling (see /task transcript).
