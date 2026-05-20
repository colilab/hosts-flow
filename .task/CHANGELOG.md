# Changelog

## [2026-05-20] — Manual & automatic update check (Sparkle)

**Type:** feature
**Ref:** [.task/version-download-update/plan.md](.task/version-download-update/plan.md)

### Changes
- Integrated **Sparkle 2** (SwiftPM, resolved at 2.9.2) so Host Flow can check for and install its own updates. New `packages:` entry in `project.yml` and a `Sparkle` product dependency on the `HostFlow` target.
- New `UpdaterStore` (`@Observable`) wraps `SPUStandardUpdaterController(startingUpdater: true, …)`: exposes `checkForUpdates()`, a two-way `automaticallyChecksForUpdates` bound to Sparkle's own persisted setting, `lastUpdateCheckDate`, and a KVO-mirrored `canCheckForUpdates` used to disable the button while a check is in flight. Injected via `.environment` into the main window, the menu-bar scene and the Settings scene.
- **Settings → Info** gains an "Automatically check for updates" toggle, a "Check for Updates…" button (disabled mid-check), and a caption showing the last check as a locale-aware relative date.
- **Menu bar menu** gains a "Check for Updates…" item between "Settings…" and "Quit".
- `Info.plist` Sparkle config: `SUFeedURL` → `https://colilab.github.io/hosts-flow/appcast.xml`, weekly `SUScheduledCheckInterval` (604800), `SUEnableAutomaticChecks = YES`, `SUAutomaticallyUpdate = NO` (always prompt), `SUEnableInstallerLauncherService = NO` (app is not sandboxed). `SUPublicEDKey` ships as an explicit **placeholder** — Sparkle safely rejects every update until the real key is pasted in.
- `Scripts/make-sparkle-keys.sh` (new) generates the dedicated Sparkle EdDSA keypair — kept separate from the helper CDHash-manifest key — and exports the private key to `~/Documents/keys-vault/`.
- `Scripts/build-release.sh` extended: requires `HOSTFLOW_SPARKLE_PRIVATE_KEY`, packages `dist/HostFlow-<version>.dmg` with `hdiutil` **after** manifest signing (no re-codesign — the daemon hash invariant holds), signs the DMG with Sparkle's `sign_update`, and emits `dist/appcast-entry.json`.
- Release automation: `Scripts/publish.sh` (new) creates the draft GitHub Release with the DMG + entry attached; `.github/workflows/release.yml` (new) triggers on stable `MAJOR.MINOR.PATCH` tags, publishes the draft, and appends an `<item>` to the `gh-pages` `appcast.xml` via `.github/scripts/append_appcast.py` (release notes rendered with `pandoc`). `Scripts/appcast-template.xml` is the starting feed.
- 4 localized keys added (EN/IT): `settings.about.check_updates`, `settings.about.auto_check`, `settings.about.last_checked`, `menubar.item.check_updates`. The menu-bar key uses the `menubar.item.*` prefix for consistency with the sibling keys, rather than the `menu.check_updates` name in the plan draft.
- Docs: `docs/release.md` §3/§5 updated and a new §9 "Sparkle update channel" (two-key trust model, key setup, appcast bootstrap, per-release dev flow, the DMG-does-not-re-sign invariant, key rotation). `README.md` gains an "Updates" section.

### Files modified
- `HostFlow/project.yml` — Sparkle SwiftPM package + target dependency.
- `HostFlow/Resources/Info.plist` — Sparkle keys (`SUPublicEDKey` placeholder).
- `HostFlow/Stores/UpdaterStore.swift` — new `@Observable` Sparkle wrapper.
- `HostFlow/App/HostFlowApp.swift` — `UpdaterStore` injected into all three scenes.
- `HostFlow/Views/Settings/SettingsView.swift` — update toggle, button, last-checked caption.
- `HostFlow/Views/MenuBar/MenuBarView.swift` — "Check for Updates…" menu item.
- `HostFlow/Resources/Localizable.xcstrings` — 4 new keys (EN/IT).
- `Scripts/make-sparkle-keys.sh`, `Scripts/build-release.sh`, `Scripts/publish.sh`, `Scripts/appcast-template.xml`.
- `.github/workflows/release.yml`, `.github/scripts/append_appcast.py`.
- `docs/release.md`, `README.md`, `.gitignore` (`dist/`).

### Verification
- `xcodegen generate` (new `UpdaterStore.swift` + Sparkle package).
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED** (Sparkle 2.9.2 resolved, `Sparkle.framework` embedded in the built `.app`).
- `append_appcast.py` exercised against `appcast-template.xml` with a fake entry: produces well-formed XML and is idempotent on re-run.
- All shell scripts pass `bash -n`; `append_appcast.py` passes `py_compile`.

### Remaining manual steps (cannot be automated from the CLI)
- Run `Scripts/make-sparkle-keys.sh` and paste the printed public key into `Info.plist` `SUPublicEDKey`.
- Bootstrap the orphan `gh-pages` branch and enable GitHub Pages (commands in `docs/release.md` §9.3).
- Local end-to-end smoke test of the update flow.

## [2026-05-18] — Sortable host records by Hostname and IP

**Type:** feature
**Ref:** [.task/sortable-records/plan.md](.task/sortable-records/plan.md)

### Changes
- Le colonne `Hostname` e `IP` nella tabella dei record di un profilo sono ora ordinabili cliccando sull'header (alterna asc/desc). Il sort è di sessione e non viene persistito; nessuna modifica al modello `HostRecord` né alla scrittura di `/etc/hosts`.
- `ProfileDetailView` introduce `@State sortOrder: [KeyPathComparator<HostRecord>]` passato a `Table(of:selection:sortOrder:)`; `filteredRecords` applica il sort sopra il filtro di search quando `sortOrder` non è vuoto.

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — stato `sortOrder`, `sortUsing:` su colonne IP/Hostname, sort nel computed `filteredRecords`.

### Verification
- `xcodebuild -scheme HostFlow -destination 'platform=macOS' -configuration Debug build` → **BUILD SUCCEEDED**.
- Smoke test UI manuale non eseguito dalla CLI — verifica visiva consigliata.

## [2026-05-18] — Apply managed hosts block on app launch

**Type:** bugfix

### Changes
- After a Mac reboot, profiles flagged as active in the database were not being applied to `/etc/hosts` until the user manually toggled something, because launch-time code only seeded data and started the file watcher without ever calling `writeHosts`.
- New `ProfileStore.applyOnLaunch(context:)` performs the same write as `writeHostsImmediate` but returns silently when the privileged helper is not installed — no `helperMissing` flag, no onboarding sheet at launch.
- `ContentView.task` now calls `applyOnLaunch` between `seedIfNeeded` and `watcher.start`, so the file is reconciled before the watcher attaches and cannot misinterpret the launch write as an external change.

### Files modified
- `HostFlow/Stores/ProfileStore.swift` — added `applyOnLaunch(context:)`.
- `HostFlow/App/ContentView.swift` — invoke `applyOnLaunch` during the initial `.task`.

## [2026-05-15] — Import JSON archive with merge/replace modes

**Type:** feature
**Ref:** [.task/features/37-import-json.md](.task/features/37-import-json.md)

### Changes
- New `ImportJSONService.parseFile(at:)` decodes the `ExportPayload` and validates `version` against `ExportPayload.currentVersion`. Errors localized: `readFailed`, `invalidFormat`, `unsupportedVersion(found:max:)`.
- New `ImportMode` enum (`.merge` / `.replace`) with localized label and description keys.
- `ProfileStore.applyImport(_:mode:context:)`: in `.replace` mode deletes every user profile (`isReadOnly == false`) first — the read-only Default profile is preserved. Then inserts new `Profile` + `HostRecord` instances (fresh UUIDs). `uniqueImportName` suffixes colliding names with `(imported)` / `(importato)` (or numbered if also taken). No `writeHosts` is triggered (imported profiles arrive inactive).
- New `ImportJSONSheet`: total profile/record counts, segmented Merge/Replace picker, mode description, Cancel/Import buttons. Choosing Replace pops a destructive `.alert` that quotes the number of user profiles that will be deleted.
- `SettingsView` Advanced row "Import…" became a `Menu` exposing "From hosts file…" (existing flow) and "From JSON…" (new flow). JSON open panel restricted to `[.json]`.
- 17 new localized keys covering the JSON import flow (sheet, modes, replace confirmation, errors, suffix), localized into EN and IT.

### Files modified
- `HostFlow/Helpers/ImportJSONService.swift` — new service, error/result types, `ImportMode`.
- `HostFlow/Stores/ProfileStore.swift` — `userProfileCount(context:)`, `applyImport(_:mode:context:)`, `uniqueImportName(_:taken:)`.
- `HostFlow/Views/Settings/ImportJSONSheet.swift` — new preview sheet with mode picker and replace confirmation.
- `HostFlow/Views/Settings/SettingsView.swift` — Import row replaced by a `Menu`, JSON open panel, error alert, sheet wiring.
- `HostFlow/Resources/Localizable.xcstrings` — added 17 keys.

### Verification
- `xcodegen generate` (new source files in `Helpers/` and `Views/Settings/`).
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Manual UI smoke test (export → merge import → replace import with confirmation, plus invalid-JSON and bumped-version error paths) not executed from CLI — visual verification recommended.

## [2026-05-15] — Import /etc/hosts file as new profile

**Type:** feature
**Ref:** [.task/features/36-import-hosts-format.md](.task/features/36-import-hosts-format.md)

### Changes
- Reused the existing `HostsFileParser.parse(_:)` (already tolerant of blank lines, marker headers, commented records, multiple hostnames per line) — no new parser code.
- New `ImportService.parseFile(at:)` reads the user-selected file as UTF-8, runs the parser, and returns an `ImportResult` (suggested profile name from the filename + parsed records). Throws `ImportError.readFailed`/`.noValidRecords` with localized descriptions.
- New `ImportProfileSheet` (preview): editable name `TextField` (defaults to the filename, live duplicate-name validation against existing profiles), record count, read-only `Table` (IP, Hostname, Enabled), Cancel/Import buttons.
- `SettingsView` Advanced section gains an "Import…" row above "Export…". `NSOpenPanel` accepts `[.plainText, .data]` so files without an extension (like `/etc/hosts`) can be selected. On parse failure or empty result, a native `.alert` is shown — the preview sheet does not open.
- On confirm: a new profile is created via `ProfileStore.addProfile` (always `isActive = false`), records are inserted with the parsed `isEnabled` flag, success surfaces through the existing HUD overlay.
- 14 new localized keys: `settings.advanced.import.*`, `import.sheet.title`, `import.records.count` (with plural variation), `import.column.*`, `import.button.import`, `error.import.*`.

### Files modified
- `HostFlow/Helpers/ImportService.swift` — new service + `ImportResult` (Identifiable) + `ImportError`.
- `HostFlow/Views/Settings/ImportProfileSheet.swift` — new preview sheet.
- `HostFlow/Views/Settings/SettingsView.swift` — Import row, open panel, error alert, preview sheet wiring, `createProfile` helper.
- `HostFlow/Resources/Localizable.xcstrings` — added 14 keys.

### Verification
- `xcodegen generate` (new source files in `Helpers/` and `Views/Settings/` required project regeneration).
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Manual UI smoke test (pick `/etc/hosts`, confirm preview, verify new inactive profile in sidebar) not executed from CLI — visual verification recommended.

## [2026-05-15] — Export all profiles as JSON

**Type:** feature
**Ref:** [.task/features/35-export-json.md](.task/features/35-export-json.md)

### Changes
- New Codable DTOs `ExportPayload`, `ProfileExport`, `RecordExport` with `ExportPayload.currentVersion = 1`. Schema intentionally tightened vs. the task spec: `id`, `isActive`, `isReadOnly` omitted to keep the format portable and to make any future import default to disabled, editable profiles with fresh UUIDs.
- New `ExportService.exportAll(profiles:)` filters out the read-only Default profile, sorts user profiles by `order`, and emits JSON with `[.prettyPrinted, .sortedKeys]`.
- `SettingsView` Advanced section gains an "Export…" row (placed above "Clean /etc/hosts"). Click triggers an asynchronous `NSSavePanel` with `allowedContentTypes = [.json]` and default filename `hostflow-export-<YYYY-MM-DD>.json` (POSIX date formatting, locale-independent).
- Success surfaces through the same HUD pattern as `ProfileDetailView` (capsule material overlay, 1.5 s auto-dismiss). Encode/write failures are presented via a native `.alert`.
- 6 new keys under `settings.advanced.export.*` localized in EN and IT.

### Files modified
- `HostFlow/Helpers/ExportPayload.swift` — new Codable DTOs.
- `HostFlow/Helpers/ExportService.swift` — new export service.
- `HostFlow/Views/Settings/SettingsView.swift` — Export row, save panel, HUD overlay, error alert; imports `UniformTypeIdentifiers`.
- `HostFlow/Resources/Localizable.xcstrings` — added 6 keys.

### Verification
- `xcodegen generate` (new source files in `Helpers/` required project regeneration).
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Manual UI smoke test (click Export, choose destination, inspect JSON output) not executed from CLI — visual verification recommended.

## [2026-05-15] — Export profile as /etc/hosts text

**Type:** feature
**Ref:** [.task/features/34-export-hosts-format.md](.task/features/34-export-hosts-format.md)

### Changes
- New `HostsFileManager.formatProfile(_:) -> String` produces a per-profile text block in `/etc/hosts` format: `# <Profile Name>` header followed by `<ip> <hostname>` lines (disabled records emitted as `# <ip> <hostname>`), trailing newline.
- `ProfileDetailView` toolbar gains an "Export" `Menu` (SF Symbol `square.and.arrow.up`) with two actions: "Copy to clipboard" and "Save to file…". Disabled on read-only profiles (Default).
- Copy uses `NSPasteboard.general`; save uses an asynchronous `NSSavePanel` (`allowedContentTypes: [.plainText]`) with default filename `<profile-name-slug>.hosts` (lowercase, spaces → dashes).
- Transient HUD overlay (regular material capsule, top-aligned, 1.5 s auto-dismiss) confirms successful copy/save without an alert.
- File-write failures surface through a native `.alert` with the underlying error message.
- New localized keys under `profile.detail.export.*` (EN base + IT) for the menu, HUD and error strings.

### Files modified
- `HostFlow/Helpers/HostsFileManager.swift` — added `formatProfile(_:)`.
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — added export menu, copy/save handlers, HUD overlay and save-error alert; imports `AppKit` and `UniformTypeIdentifiers`.
- `HostFlow/Resources/Localizable.xcstrings` — added 7 keys (`profile.detail.export.menu/copy/save/copied/saved/save.panel.title/save.error.title`).

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Manual UI smoke test (toggle menu, copy, save panel, HUD timing) not executed from CLI — visual verification recommended.

## [2026-05-15] — Internationalization (English + Italian)

**Type:** feature

### Changes
- Added String Catalog `Localizable.xcstrings` with hierarchical keys (e.g. `sidebar.button.new_profile`, `profile.detail.column.ip`) for the English source and Italian translations. Plural variation included for the menu-bar tooltip.
- Added `InfoPlist.xcstrings` localizing `CFBundleDisplayName`, `CFBundleName`, `NSHumanReadableCopyright`.
- Set development language to `en` in `project.yml` and `Info.plist`; declared `CFBundleLocalizations = [en, it]`.
- Replaced every hardcoded user-facing string in views, alerts, confirmation dialogs, table columns, menus, toggles, content-unavailable views, helper onboarding and validation errors with `LocalizedStringKey` or `String(localized:)` lookups.
- `AppearanceMode.label: String` became `labelKey: LocalizedStringKey`.
- Added `PreferredLanguage` enum (`system | en | it`) on `AppSettings`, persisted via `UserDefaults`, with a `resolvedLocale` computed property.
- `HostFlowApp` injects `.environment(\.locale, appSettings.resolvedLocale)` into the main window, menu-bar scene and Settings scene — runtime language switching without restart.
- New language picker in `SettingsView` (`settings.section.general` → `settings.language.picker`).
- Seed `Default` profile name and duplicate suffixes (`(copy)` / `(copia)`) localized at creation time via `String(localized:)`/`String(format:)`.
- Helper-side `HelperError.errorDescription` left as hardcoded English: the helper daemon does not ship resources, and the message is serialized over XPC.

### Files modified
- `HostFlow/project.yml` — `developmentLanguage: en`, registered the two `.xcstrings` files in the target sources.
- `HostFlow/Resources/Info.plist` — added `CFBundleDevelopmentRegion` and `CFBundleLocalizations`.
- `HostFlow/Resources/Localizable.xcstrings` — new.
- `HostFlow/Resources/InfoPlist.xcstrings` — new.
- `HostFlow/App/HostFlowApp.swift` — locale environment override on all scenes.
- `HostFlow/App/ContentView.swift` — localized alert and empty state.
- `HostFlow/Stores/AppSettings.swift` — `PreferredLanguage`, `labelKey`, `resolvedLocale`.
- `HostFlow/Stores/ProfileStore.swift` — localized seed name and duplicate suffix.
- `HostFlow/Views/Sidebar/SidebarView.swift`, `AddProfileSheet.swift`.
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`, `AddRecordSheet.swift`, `EditRecordSheet.swift`.
- `HostFlow/Views/MenuBar/MenuBarView.swift` — localized tooltip with plural variation.
- `HostFlow/Views/Settings/SettingsView.swift` — language picker, localized alerts and labels.
- `HostFlow/Views/Settings/HelperSettingsSection.swift`.
- `HostFlow/Views/Onboarding/HelperOnboardingSheet.swift`.
- `HostFlow/Helpers/HostValidator.swift` — `ValidationError.errorDescription` uses localized lookups.
- `HostFlow/Helpers/HelperInstaller.swift` — localized installer error messages and authorization prompts.

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Produced `en.lproj` and `it.lproj` inside the built `.app`, each containing `Localizable.strings`, `Localizable.stringsdict` and `InfoPlist.strings`.

## [2026-05-15] — Style conventions cleanup

**Type:** chore

### Context
Follow-up to the native components refactor. Audit found 5 residual spacings off the 4/8pt grid, 1 fixed font size, and 1 redundant disabled-state styling that diverged from `.claude/conventions.md`. No design decisions — just constants brought back onto the grid and one semantic font swap.

### Changes
- **SidebarView.swift** `ProfileRowView`: `HStack(spacing: 6)` → `8`; `.padding(.vertical, 2)` → `4`.
- **ProfileDetailView.swift** `toolbar`: `.padding(.vertical, 10)` → `8`.
- **ProfileDetailView.swift** `recordsList` (IP + Hostname columns): removed redundant `.opacity(record.isEnabled ? 1.0 : 0.5)`. Disabled-state look is now driven only by `.foregroundStyle(record.isEnabled ? .primary : .secondary)`.
- **AddProfileSheet.swift**: inner field+error `VStack(spacing: 6)` → `8`.
- **SettingsView.swift** "Pulisci /etc/hosts" row: `VStack(spacing: 2)` → `4`.
- **HelperOnboardingSheet.swift**: header lock icon `.font(.system(size: 32))` → `.font(.largeTitle)` (semantic, ≈34pt).

### Files modified
- `HostFlow/Views/Sidebar/SidebarView.swift`
- `HostFlow/Views/Sidebar/AddProfileSheet.swift`
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
- `HostFlow/Views/Settings/SettingsView.swift`
- `HostFlow/Views/Onboarding/HelperOnboardingSheet.swift`

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Visual delta is minimal by design (1–2pt shifts, slightly larger lock icon, disabled rows slightly less faded). Manual eyeballing recommended.

## [2026-05-15] — Native SwiftUI components refactor

**Type:** refactor

### Context
UI review identified four spots where custom or non-native constructs diverged from `.claude/architecture.md` / `.claude/conventions.md`. Migrated points 1, 2, 3, 5 to native SwiftUI APIs; point 4 (custom menu bar asset icon) intentionally left as-is. No functional changes for the end user — same behavior, native components.

### Changes
- **HostFlowApp.swift**: removed `.windowStyle(.hiddenTitleBar)` from the main `Window` scene. The standard title bar enables the native sidebar toggle and provides the toolbar slot where `.searchable` places its field.
- **ContentView.swift**: replaced `HSplitView` with `NavigationSplitView { sidebar } detail: { ... }`. Sidebar column uses `.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)`; detail column uses `.navigationSplitViewColumnWidth(min: 400, ideal: 600)`. Applied `.navigationSplitViewStyle(.balanced)`. Removed `.ignoresSafeArea(.all, edges: .top)` (no longer needed without hidden title bar).
- **SidebarView.swift**: removed the outer `VStack(spacing: 0)` and the custom footer (`HStack` with `frame(height: 36)` after a `Divider`). The footer (`Nuovo profilo` button, `ProgressView`, `SettingsLink`) is now attached to the `List` via `.safeAreaInset(edge: .bottom, spacing: 0)` with native padding (horizontal 12, vertical 8) and `.background(.bar)` for the native sidebar footer chrome.
- **SidebarView.swift**: deleted the private `RecordDropModifier` `ViewModifier`. Drop handling is now inline in `ProfileRowView.body`: the row is built into a local `let row`, then `if profile.isReadOnly { row } else { row.dropDestination(...) }`. Read-only profiles no longer register a drop target at all.
- **ProfileDetailView.swift**: removed the custom `searchBar` computed property (HStack + magnifying glass + plain TextField + xmark button with manual background/stroke). Replaced with `.searchable(text: $searchText, prompt: "Cerca IP o hostname")` on the view root — the search field now lives in the window toolbar with standard macOS behavior (⌘F focus, native dismiss).

### Files modified
- `HostFlow/App/HostFlowApp.swift` — removed hidden title bar style.
- `HostFlow/App/ContentView.swift` — `HSplitView` → `NavigationSplitView` with native column widths and balanced style.
- `HostFlow/Views/Sidebar/SidebarView.swift` — sidebar footer via `safeAreaInset`; `RecordDropModifier` deleted, drop applied inline.
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — custom search bar replaced by `.searchable`.

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → **BUILD SUCCEEDED**.
- Manual UX checks to run in the app: native sidebar toggle in toolbar, column width constraints (180–320 / ≥400), `.searchable` filters records and shows `ContentUnavailableView.search` when empty, sidebar footer (button / progress / settings) renders with native divider, drag-and-drop record from `Table` onto a non-read-only sidebar row still highlights and moves, drop on read-only profiles produces no highlight.

## [2026-05-15] — Spostamento record tra profili

**Type:** feature

### Context
Aggiunta la possibilità di spostare uno o più `HostRecord` da un profilo modificabile a un altro profilo modificabile, sia tramite context menu (sottomenu "Sposta in") sia via drag & drop dalla tabella record alla riga di un profilo nella sidebar. I profili read-only sono esclusi sia come sorgente sia come destinazione. Il warning visivo esistente continua a indicare eventuali duplicati nel profilo destinazione (lo spostamento avviene comunque). Dopo lo spostamento viene schedulata una riscrittura di `/etc/hosts`.

### Changes
- **ProfileStore.swift**: nuovo helper `moveRecords(_:to:context:)`. Guard su destinazione/sorgente read-only e su record già appartenenti al destinazione; riassegna `record.profile = destination` (la relationship inversa SwiftData aggiorna gli array), `try? context.save()` e `scheduleWrite(context:)`.
- **HostRecordTransfer.swift** (nuovo): struct `Codable, Transferable` con singolo `id: UUID`, `CodableRepresentation(contentType: .hostFlowRecord)`. Aggiunta estensione `UTType.hostFlowRecord` con identifier `com.colilab.hostflow.hostrecord`.
- **Info.plist**: registrato `UTExportedTypeDeclarations` per `com.colilab.hostflow.hostrecord` (conforms a `public.data`).
- **ProfileDetailView.swift**:
  - Tabella migrata alla forma `Table(of:selection:) { columns } rows: { ... }` per consentire `.draggable(HostRecordTransfer(id:))` per riga (solo se `!profile.isReadOnly`).
  - Context menu: nuovo `Menu("Sposta in")` con elenco profili modificabili diversi dal corrente (ordinati per `order`). Voce nascosta su profilo sorgente read-only e disabilitata se non ci sono destinazioni.
  - Helper `moveRecords(ids:to:)` che risolve gli ID in record presenti nel profilo e delega allo store; svuota `selectedRecordIDs` dopo l'azione.
- **SidebarView.swift**:
  - `ProfileRowView` ora espone `.dropDestination(for: HostRecordTransfer.self)` (via `RecordDropModifier` per gestire il disable su read-only senza rompere il type-check del view builder). Highlight con `Color.accentColor.opacity(0.2)` quando `isTargeted`.
  - Handler drop: fetch dei `HostRecord` per id via `FetchDescriptor` + `#Predicate` e chiamata a `store.moveRecords(...)`.

### Files modified
- `HostFlow/Stores/ProfileStore.swift`
- `HostFlow/Models/HostRecordTransfer.swift` (nuovo)
- `HostFlow/Resources/Info.plist`
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
- `HostFlow/Views/Sidebar/SidebarView.swift`

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug build` → **BUILD SUCCEEDED**.
- Validazione UX (menu "Sposta in", drag dalla tabella, highlight + drop sulla sidebar, esclusione read-only, trigger scrittura, svuotamento selezione) da effettuare manualmente lanciando l'app.

## [2026-05-15] — MenuBarExtra migrato a menu nativo macOS

**Type:** refactor

### Context
Il `MenuBarExtra` usava `.menuBarExtraStyle(.window)` con un popover SwiftUI custom (`MenuItemButtonStyle`, `MenuBarProfileRow`, hover handling manuale, `Toggle .switch` su ogni riga profilo). Richiesta: passare al menu nativo macOS (`.menu`) per coerenza con HIG, gestendo il toggle del profilo — non rappresentabile come componente nativo top-level — tramite submenu che si apre in hover.

### Changes
- **HostFlowApp.swift**: `.menuBarExtraStyle(.window)` → `.menuBarExtraStyle(.menu)`.
- **MenuBarView.swift** riscritto:
  - Profilo non read-only → `Menu` con label che mostra `Label(name, systemImage: "checkmark")` se attivo o `Text(name)` se inattivo. Submenu contiene una sola `Toggle("Attivo", isOn: ...)` con binding custom che, oltre a mutare `profile.isActive`, esegue `context.save()` + `store.scheduleWrite(context:)`.
  - Profilo read-only ("Default") → `Button` disabilitato con `Label(name, systemImage: "lock.fill")`, nessun submenu (l'unica azione possibile sarebbe non-funzionante).
  - Azioni in basso: `Button "Apri Host Flow"`, `SettingsLink "Impostazioni…"`, `Divider`, `Button "Esci"` con `keyboardShortcut("q", .command)`. Divider sopra le azioni solo se la lista profili non è vuota.
  - Stato vuoto: nessun placeholder, solo le azioni in basso.
  - Rimossi: `MenuItemButtonStyle`, `MenuItemButtonBody`, `MenuBarProfileRow`, il `VStack` root con `.frame(width: 280)`, e l'`@Environment(AppSettings.self)` non più necessario.
- `MenuBarLabel` invariato (icona + colore in base a `lastWriteError` / `activeProfiles`).

### Files modified
- `HostFlow/App/HostFlowApp.swift`
- `HostFlow/Views/MenuBar/MenuBarView.swift`

### Verification
- `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug build` → **BUILD SUCCEEDED**.
- Validazione runtime UX (apertura menu, submenu in hover, checkmark, toggle write trigger, lock.fill su Default, azioni bottom) da effettuare manualmente lanciando l'app.

## [2026-05-14] — Dark mode visual audit

**Type:** chore

### Context
Static audit of all SwiftUI views to verify dark-mode compliance per project conventions (`conventions.md` § Design HIG: only semantic colors). Goal was to detect hardcoded colors, non-adaptive assets, and contrast issues.

### Outcome
No code changes required. The codebase is already fully compliant:
- All foreground/background colors are SwiftUI semantic (`.primary`, `.secondary`, `.red`, `.orange`, `.tint`) or AppKit adaptive (`Color(nsColor: .controlBackgroundColor)`, `.separatorColor`, `.controlAccentColor`).
- `MenuBarIcon` is a template `.symbolset` — tints automatically.
- `MenuItemButtonStyle` uses `Color.white` on `Color.accentColor` for hover — verified as the standard macOS menu pattern (works in both modes), kept as-is.
- `AppIcon` dark variant impossible in `.appiconset` on macOS (already documented 2026-05-13). The current icon design works in both themes; tinted variant would require migration to `.icon` format (Icon Composer / Xcode 16+) — out of scope.

### Files modified
None.

## [2026-05-13] — App icon + custom menu bar icon

**Type:** feature

### Context
L'app non aveva un'icona custom (`AppIcon.appiconset` conteneva solo `Contents.json` vuoto, `.app` mostrava icona generica in Finder/About) e il `MenuBarExtra` usava 3 SF Symbols dinamici (`network` / `network.slash` / `network.badge.shield.half.filled`). Aggiunti entrambi gli asset definitivi forniti dall'utente.

### Changes
- **AppIcon**: master 1024×1024 PNG fornito dall'utente (`icon_512x512@2x.png`), generate le altre 9 size standard macOS con `sips` (16/32/128/256/512 @1x e @2x). Tutte e 10 in `HostFlow/Resources/Assets.xcassets/AppIcon.appiconset/` con `Contents.json` cablato. `Assets.car` ora contiene 21 entries `AppIcon` (10 size × srgb + extended sRGB/P3 + 1 thumbnail) e `AppIcon.icns` viene generato in `Contents/Resources/`.
- **CFBundleIconName** aggiunta in `Info.plist` (mancava completamente — senza questa chiave macOS non sa quale icon set caricare da `Assets.car`, anche se l'asset è compilato correttamente). Bug latente che preveniva qualsiasi icona di apparire.
- **project.yml fix**: `Assets.xcassets` era dichiarata sotto la chiave `resources:` che **non esiste** in xcodegen — veniva ignorata silenziosamente, risultato: `0` riferimenti ad `Assets.xcassets` nel `.xcodeproj` generato. Spostata sotto `sources:` (xcodegen auto-detecta xcassets nei sources e li tratta come resources). Bug latente analogo al precedente.
- **MenuBarIcon** custom: SVG esportato dall'utente con "Export Symbol" da SF Symbols app, salvato in nuovo `HostFlow/Resources/Assets.xcassets/MenuBarIcon.symbolset/icon.svg` con `Contents.json` formato Symbol Image Set (`idiom: universal`). Compilato come 17 entries multi-weight in `Assets.car` (Encoding=Gray).
- `MenuBarLabel` in `MenuBarView.swift` modificato: rimossa funzione `iconName` (non più necessaria con strategia "1 sola icona statica" scelta dall'utente), `Image(systemName: iconName)` sostituito da `Image("MenuBarIcon")`. Mantenute funzioni `iconColor` e `tooltip` invariate (vedi nota sotto).

### Limitazioni macOS scoperte e accettate

1. **Variant dark/tinted in `.appiconset` per macOS — NON supportate**. Verificato empiricamente con `actool` (Xcode 26.5): le `appearances` con `luminosity: dark` o `luminosity: tinted` quando `idiom: mac` vengono **silenziosamente ignorate** dal compilatore (nessun errore né warning, ma le entry non finiscono in `Assets.car`). Differenze per piattaforma: iOS/iPadOS 18+ supporta entrambi in `.appiconset`; macOS 15+ tinted icons richiedono il nuovo formato `.icon` di Icon Composer (Xcode 16+, incompatibile con `.appiconset`); su macOS la dark variant storicamente non esiste come asset separato — il design dell'icona deve avere contrasto sufficiente per entrambi i mode. La nostra squircle chiara funziona già bene in entrambi senza variant. PNG tinted forniti dall'utente caricati e poi cancellati come orfani.

2. **Custom MenuBarIcon resta monochrome nella status bar**. `NSStatusItem` (sotto a `MenuBarExtra`) forza il rendering monochrome con `controlTextColor` sui Symbol Image Set custom, ignorando `.foregroundStyle(_:)` applicato a `Image("MenuBarIcon")`. Per gli SF Symbols nativi questo non succede perché AppKit ha un percorso speciale che pre-renderizza il colore in bitmap; per i custom symbols quel percorso non c'è — anche se l'SVG è stato esportato direttamente con "Export Symbol" dall'app ufficiale SF Symbols. Workaround `Color.mask { Image }` tentato e revertito perché rompe la geometria che `MenuBarExtra` si aspetta dalla label view (icona invisibile, solo cerchio scuro al click). Workaround alternativi (bypass `MenuBarExtra` con AppKit + `NSStatusItem` custom, oppure ibrido custom+SF Symbol) non implementati per costo/benefit. Lo stato dei profili e degli errori resta comunicato via tooltip al hover e via popover al click. La logica `iconColor` resta nel codice ma di fatto inerte sulla status bar.

### Files modified
- `HostFlow/Resources/Assets.xcassets/AppIcon.appiconset/` — 10 PNG + `Contents.json` aggiornato.
- `HostFlow/Resources/Assets.xcassets/MenuBarIcon.symbolset/` — nuova cartella con `icon.svg` + `Contents.json`.
- `HostFlow/Resources/Info.plist` — aggiunta `CFBundleIconName = AppIcon`.
- `HostFlow/project.yml` — `Assets.xcassets` spostata da `resources:` (key inesistente) a `sources:`.
- `HostFlow/HostFlow.xcodeproj/project.pbxproj` — rigenerato con xcodegen, ora include il riferimento a `Assets.xcassets`.
- `HostFlow/Views/MenuBar/MenuBarView.swift` — `MenuBarLabel` ora usa `Image("MenuBarIcon")`, rimossa funzione `iconName`.

## [2026-05-12] — MenuBar popover: hover visual feedback + layout polish

**Type:** feature

### Context
Il popover del `MenuBarExtra` usa `.menuBarExtraStyle(.window)` (custom SwiftUI, non `NSMenu` nativo): di conseguenza i bottoni in `.buttonStyle(.plain)` non offrivano alcun feedback visivo all'hover sulle voci "Apri Host Flow", "Impostazioni...", "Esci". Inoltre il layout del popover aveva alcune scelte da rifinire (titolo ridondante, distinguibilità del toggle nelle righe profilo).

### Changes
- Nuovo `MenuItemButtonStyle: ButtonStyle` (private) + `MenuItemButtonBody` view privata che traccia lo stato hover via `@State isHovered` + `.onHover`. Quando `isHovered || configuration.isPressed`, la label dipinge background `Color.accentColor` su `RoundedRectangle(cornerRadius: 4)` inset di 5pt dai bordi del popover e foreground `Color.white`; altrimenti background trasparente e foreground `Color.primary`. Padding interno `horizontal 7 / vertical 4`, `frame(maxWidth: .infinity, alignment: .leading)` per allargare l'area cliccabile su tutta la riga, `contentShape(Rectangle())` perché l'hover scatti su tutta la pillola (non solo sulla label).
- Applicato `.buttonStyle(MenuItemButtonStyle())` ai tre bottoni "Apri Host Flow" (`Label` + `macwindow`), "Impostazioni..." (`SettingsLink` + `gearshape`) e "Esci" (`Label` + `power`, con `keyboardShortcut("q", modifiers: .command)` già in essere).
- Rimosso il titolo "Host Flow" e il `Divider` che lo seguiva — il titolo è ridondante con il `MenuBarLabel` già presente in barra di stato.
- Aggiunto sottotitolo "Profili" (`font(.caption)`, `.fontWeight(.semibold)`, `foregroundStyle(.secondary)`, padding `horizontal 12 / top 10 / bottom 4`) sopra l'elenco profili — solo nel ramo non-vuoto, lo stato vuoto continua a renderizzare il proprio `tray` SF Symbol + copy.
- `MenuBarProfileRow` NON usa hover background sulla riga: durante l'iterazione era stato applicato per consistenza con i bottoni d'azione, ma rendeva il `Toggle` indistinguibile sullo sfondo accent. Ripristinata la riga "piatta" con `padding(horizontal 12, vertical 5)`. Aggiunto invece `NSCursor.pointingHand.push()`/`pop()` su `.onHover` del solo `Toggle`, con guard `!profile.isReadOnly` (il profilo Default non deve mostrare il cursor pointer perché il toggle è `.disabled`).

### Out of scope
- Border radius del popover (sperimentato un `NSViewRepresentable` `PopoverCornerRadiusAdjuster` che impostava `contentView.layer.cornerRadius = 6` sull'`NSWindow` del popover, rimosso su richiesta esplicita dell'utente per tornare al border radius di sistema).
- Menu app standard nella top bar di sistema (titolo applicazione + menu Apple/File/Edit/Window/Help quando la finestra principale è in primo piano): è un effetto voluto di `LSUIElement = true` in `Info.plist`, documentato nel `README.md` sotto la sezione Features.

### Files modified
- `HostFlow/Views/MenuBar/MenuBarView.swift` — nuove `MenuItemButtonStyle`/`MenuItemButtonBody`, layout del popover ripulito (no titolo, sottotitolo "Profili"), `MenuBarProfileRow` con cursor pointer sul solo toggle.
- `README.md` — nota "Menu bar app behavior" sotto Features che spiega l'assenza di Dock icon e menu di sistema (`LSUIElement = true`) come scelta di design intenzionale.

## [2026-05-12] — Settings: "Pulisci" ora cancella tutti i profili Host Flow

**Type:** feature

### Context
Revisione del task `.task/completed/settings-reset-block/spec.md`: il comportamento precedente disattivava i profili attivi e rimuoveva il blocco da `/etc/hosts` ma lasciava intatti profili e record. Nuova semantica: il bottone è un reset completo dei dati Host Flow, mantenendo solo il profilo Default (read-only, specchio di `/etc/hosts` via watcher).

### Changes
- `ProfileStore.resetManagedBlock(context:)` riscritta: invece di iterare i profili attivi e impostare `isActive = false`, ora fa `context.delete` su tutti i profili con `isReadOnly == false` (cascade SwiftData elimina automaticamente i loro `HostRecord` grazie a `@Relationship(deleteRule: .cascade)`), poi forza `Default.isActive = true` cosicché il Default diventa l'unico profilo attivo. Il resto del flusso (cancel debouncer, `HelperInstaller.refreshStatus` → `helperMissing` se non installato, `Task @MainActor` con `removeManagedBlock()` e `lastWriteAt`/`lastWriteError`) è invariato.
- `SettingsView` alert message aggiornato da "Verrà rimosso il blocco Host Flow da /etc/hosts. I tuoi profili NON saranno cancellati." → "Verranno rimossi tutti i profili Host Flow e i loro record. Il blocco verrà rimosso da /etc/hosts. L'operazione è irreversibile." per riflettere la nuova semantica distruttiva. Label bottone ("Pulisci") e descrizione di sezione restano invariati su richiesta esplicita.
- Feedback visivo: la sidebar reagisce automaticamente alla cancellazione via `@Query` SwiftData — nessuna logica aggiuntiva richiesta.
- Notifica di sistema esplicitamente **non** aggiunta: l'app è sempre in foreground durante il reset, quindi macOS consegnerebbe la notifica silenziosamente al Notification Center senza banner. Decisione presa dopo un primo tentativo con `UNUserNotificationCenter` che è stato rimosso (un'opzione sarebbe stata implementare `UNUserNotificationCenterDelegate.willPresent` per forzare il banner in foreground, ma il costo/benefit non giustifica l'aggiunta del delegate + import + entitlement management).

### Files modified
- `HostFlow/Stores/ProfileStore.swift` — `resetManagedBlock(context:)` ora elimina i profili non-readOnly e attiva il Default.
- `HostFlow/Views/Settings/SettingsView.swift` — testo dell'alert di conferma aggiornato.
- `.task/completed/settings-reset-block/spec.md` — riallineato col nuovo comportamento (obiettivo, requisiti, checklist, note tecniche).

## [2026-05-12] — Settings: sezione "Info" con versione app e copyright

**Type:** feature

### Changes
- Nuova sezione "Info" in `SettingsView` con `LabeledContent("Versione", value: Bundle.main.appVersion)` e footer `© 2026 Colilab` (caption, secondary). Sostituisce la riga "Versione" precedente che leggeva il valore direttamente da `Bundle.main.infoDictionary` inline.
- Nuovo helper `Bundle.appVersion` / `Bundle.appBuild` (legge rispettivamente `CFBundleShortVersionString` e `CFBundleVersion`, fallback `—`) in `HostFlow/Helpers/Bundle+AppInfo.swift`. `appBuild` non è esposto attualmente nella UI ma resta disponibile come API.
- `project.yml` ora definisce `MARKETING_VERSION: "1.0.0"` e `CURRENT_PROJECT_VERSION: "1"` in `settings.base` come single source of truth, e `Info.plist` referenzia entrambe le chiavi via `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. Bump di versione/build ora si fa in un solo punto (`project.yml`) invece che editare l'Info.plist hardcoded.
- Versione adottata in formato semver completo (`major.minor.patch` = `1.0.0`) per coerenza con la convenzione App Store.

### Out of scope
- Link "Sito web" / "Codice sorgente" (escluso esplicitamente dall'utente per questa iterazione)

### Files modified
- `HostFlow/project.yml` — `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `settings.base`.
- `HostFlow/Resources/Info.plist` — `CFBundleShortVersionString` / `CFBundleVersion` ora riferiscono le build settings.
- `HostFlow/Helpers/Bundle+AppInfo.swift` — nuovo helper.
- `HostFlow/Views/Settings/SettingsView.swift` — sezione "Info" con `LabeledContent` + footer copyright.

## [2026-05-12] — Settings: "Pulisci /etc/hosts" rimuove il blocco gestito da Host Flow

**Type:** feature

### Changes
- Nuova `HostsFileManager.removeManagedBlock()` (async throws): legge `/etc/hosts`, rimuove l'intervallo dai marker `# --- Host Flow Start ---` al `# --- Host Flow End ---` (inclusi), assorbe anche la newline separatrice immediatamente precedente se vuota per evitare doppi blank-line residui, poi scrive via `HostsXPCClient`. Se i marker non sono presenti la write avviene comunque sullo stesso contenuto (no-op contenutistico). Nuova `hasManagedBlock()` sincrona che riusa il read raw e cerca i due marker — usata per il gating del bottone.
- Nuova `ProfileStore.resetManagedBlock(context:)` che orchestra il reset in tre passi: (1) cancella eventuale debouncer pendente perché un write coalescente subito dopo ricreerebbe il blocco, (2) imposta `isActive = false` su tutti i profili attivi **non read-only** (il profilo Default resta attivo — già escluso dal blocco gestito via `buildBlock` perché `isReadOnly == true`, quindi disattivarlo sarebbe un side-effect visibile sulla sidebar senza alcun impatto sul blocco), (3) invoca `removeManagedBlock()` via `Task @MainActor` riusando lo stesso pattern di `writeHostsImmediate` per `isWritingHosts`/`lastWriteError`/`lastWriteAt` e per il pre-flight `HelperInstaller.refreshStatus()` → `helperMissing` se non installato. I record dentro i profili NON vengono toccati, come richiesto dal copy dell'alert.
- Nuova sezione "Avanzate" in `SettingsView` con `Button("Pulisci")` `.buttonStyle(.borderedProminent) .tint(.red)`, sottotitolo `caption` "Rimuove il blocco gestito da Host Flow. I profili non saranno cancellati.", disabled finché `hasManagedBlock == false` o `store.isWritingHosts == true`. Alert nativo di conferma (titolo "Pulisci /etc/hosts", messaggio "Verrà rimosso il blocco Host Flow da /etc/hosts. I tuoi profili NON saranno cancellati.", bottoni "Annulla" cancel role / "Rimuovi" destructive role) prima di invocare l'azione.
- Stato `hasManagedBlock` calcolato in `.onAppear` e refreshato su `.onChange(of: store.lastWriteAt)` — alla luce della discussion preliminare ho scelto questo over un watch reattivo (HostsFileWatcher) perché Settings è una finestra effimera e tutte le mutazioni che cambiano lo stato del blocco passano comunque per `lastWriteAt`.
- `Settings` scene in `HostFlowApp` ora inietta anche `modelContainer(container)` e `environment(profileStore)` (prima solo `appSettings`), perché la sezione "Avanzate" ha bisogno di entrambi per fare il reset.

### Files modified
- `HostFlow/Helpers/HostsFileManager.swift` — `removeManagedBlock()`, `hasManagedBlock()`, private `stripBlock(from:)`.
- `HostFlow/Stores/ProfileStore.swift` — `resetManagedBlock(context:)`.
- `HostFlow/Views/Settings/SettingsView.swift` — sezione "Avanzate", stato locale `hasManagedBlock`/`showResetConfirm`, alert conferma.
- `HostFlow/App/HostFlowApp.swift` — `Settings` scene ora riceve `modelContainer` + `ProfileStore` via environment.

## [2026-05-12] — Settings: Appearance picker (System/Light/Dark) override applied to all scenes

**Type:** feature

### Changes
- `AppearanceMode` ora espone `colorScheme: ColorScheme?` (nil per `.system`, `.light`/`.dark` per gli altri casi).
- `AppSettings` espone computed `preferredColorScheme: ColorScheme?` derivato da `appearanceMode`.
- `HostFlowApp` applica `.preferredColorScheme(appSettings.preferredColorScheme)` su `Window`, popover di `MenuBarExtra` e scena `Settings`. Cambio live senza restart; persistenza già esistente in `UserDefaults`.

### Files modified
- `HostFlow/Stores/AppSettings.swift` — import `SwiftUI`, `AppearanceMode.colorScheme`, `AppSettings.preferredColorScheme`.
- `HostFlow/App/HostFlowApp.swift` — modifier `.preferredColorScheme` sulle tre scene.

## [2026-05-11] — MenuBar "Apri Host Flow" and "Esci" polished to spec

**Type:** feature

### Changes
- Main `WindowGroup` is now identified as `"main"`, so `openWindow(id: "main")` can resurrect it after the user closes the window.
- MenuBar "Apri Host Flow" button switched from `NSApp.windows.first?.makeKeyAndOrderFront` to `openWindow(id: "main")` (still activates the app first). Label is now `Label("Apri Host Flow", systemImage: "macwindow")`.
- MenuBar "Esci" button now uses `Label("Esci", systemImage: "power")` and `.keyboardShortcut("q", modifiers: .command)` so ⌘Q is shown and invokable from the popover.

### Files modified
- `HostFlow/App/HostFlowApp.swift` — `WindowGroup(id: "main")`.
- `HostFlow/Views/MenuBar/MenuBarView.swift` — `@Environment(\.openWindow)`, restyled Apri/Esci buttons, ⌘Q shortcut.

## [2026-05-11] — MenuBar status icon reacts to active profiles and write errors

**Type:** feature

### Changes
- New `MenuBarLabel` view drives the menubar symbol reactively from `@Query` over active, non-readonly profiles and `ProfileStore.lastWriteError`:
  - write error → `network.badge.shield.half.filled`, red
  - 0 active profiles → `network.slash`, secondary
  - N active profiles → `network`, accent color
- Symbols use `.symbolRenderingMode(.hierarchical)` for native look.
- Native tooltip via `.help(...)` summarises state: "Host Flow — N profili attivi" / "Host Flow — Errore scrittura /etc/hosts".
- `MenuBarExtra` switched from the `systemImage:` initializer to the `content:label:` form so the icon can be a SwiftUI view; `modelContainer` + `ProfileStore` environment are injected on both branches.

### Files modified
- `HostFlow/Views/MenuBar/MenuBarView.swift` — added `MenuBarLabel`.
- `HostFlow/App/HostFlowApp.swift` — `MenuBarExtra` uses `MenuBarLabel` as label.

## Also fixed (this session) — XPC continuation leak in writeHosts

The previous `HostsXPCClient.writeHosts` could leak its continuation when the XPC channel was rejected/invalidated, because the proxy's error handler was empty. Reworked so the proxy is obtained inside `withCheckedThrowingContinuation` with an error handler that resumes via a `ResumeOnce` guard (idempotent against double-resume if both reply and error handler fire).

### Files modified
- `HostFlow/Helpers/HostsXPCClient.swift` — fix leak; `connect()` now returns the `NSXPCConnection`.

## [2026-05-11] — MenuBar profile list polished to spec

**Type:** feature

### Changes
- Popover root width increased from 220pt to 280pt to match spec.
- Empty state now renders a centered `tray` SF Symbol plus the full copy "Nessun profilo. Crea il primo dalla finestra principale.".
- Profile row layout refactored to sidebar-style: `HStack { Text(name) + optional lock icon + Spacer + Toggle(labelsHidden) }`, instead of wrapping the label inside the `Toggle`. Toggle keeps `.toggleStyle(.switch)` and `.controlSize(.mini)` for visual parity with `SidebarView`.
- No record-count badge added (explicitly excluded during grilling).

### Files modified
- `HostFlow/Views/MenuBar/MenuBarView.swift` — width, empty state, row layout.

## [2026-05-11] — /etc/hosts external-edit watcher syncs Default profile

**Type:** feature

### Changes
- New `HostsFileWatcher` (`@MainActor`) monitors `/etc/hosts` via `DispatchSource.makeFileSystemObjectSource` on a `O_EVTONLY` file descriptor (events: `.write`, `.delete`, `.rename`, `.extend`, `.attrib`).
- Event handler debounces 300ms then triggers a sync — but only if `ProfileStore.isWritingHosts == false` and the file mtime is more than ±2s away from `lastWriteAt` (belt-and-suspenders against feedback loops from our own writes).
- On `.delete` / `.rename` (atomic replace), watcher detaches the source, reopens the fd with exponential backoff (50/100/200/500/1000/2000 ms, ~5s budget), then forces a sync because the contents likely just changed.
- New `ProfileStore.syncDefaultFromFile(context:)` performs a structural diff against the Default profile (the `isReadOnly` one): records keyed by `(ip, hostname)`. Missing keys → insert; vanished keys → delete; matching key with different `isEnabled` → update in place. Idempotent — re-saving identical content produces no changes (no loop).
- New `HostsFileParser.parseUnmanaged(_:)` exposes the existing pre/post-block parsing for direct consumption by the watcher (without re-reading the file).
- `ContentView` now owns a `@State HostsFileWatcher()` and starts it in the existing `.task` right after `store.seedIfNeeded(...)`.

### Files modified
- `HostFlow/Helpers/HostsFileWatcher.swift` — new file, watcher implementation.
- `HostFlow/Helpers/HostsFileParser.swift` — extracted `parseUnmanaged(_:)` helper.
- `HostFlow/Stores/ProfileStore.swift` — added `syncDefaultFromFile(context:)` with structural diff.
- `HostFlow/App/ContentView.swift` — owns the watcher and starts it after seed.
- `HostFlow/HostFlow.xcodeproj/project.pbxproj` — regenerated via xcodegen to pick up the new file.

## [2026-05-11] — Hosts write — debounced trigger (500ms) + last-write timestamp + quit-time flush

**Type:** feature

### Context
Task `.task/features/22-hosts-trigger.md`. Each mutation (profile toggle, record toggle, add/edit/delete record, reorder) was calling `ProfileStore.writeHosts` synchronously, so a burst of 5 rapid toggles fired 5 separate XPC writes to the helper. Adds a debounce layer that coalesces bursts into a single write, plus the `lastWriteAt` timestamp the upcoming watcher task (23) needs to distinguish app writes from external edits.

### Changes
- `ProfileStore` new public API:
  - `scheduleWrite(context:)` — cancels any pending debouncer Task and schedules a fresh one with `Task.sleep(for: .milliseconds(500))`. 5 toggles in 200ms collapse to a single write.
  - `flushPendingWrite(context:)` — if a debouncer is pending, cancels it and runs the write immediately. Wired to `NSApplication.willTerminateNotification` from `ContentView` so a quit within the 500ms window still persists the last mutation (best-effort: the XPC message dispatches to the helper, which runs as root and is independent of the GUI process lifecycle — no synchronous wait on the reply).
  - `writeHosts(context:)` retained but now also cancels the debouncer first; used only by the retry-from-error alert and post-helper-install trigger (immediate UX expected on those paths).
  - `private writeHostsImmediate(context:)` — the previous body of `writeHosts`, now invoked by all three public entry points.
- `lastWriteAt: Date?` is `private(set)`, set after a successful XPC write completes. Exposed for the watcher in task 23 (±2s mtime window).
- `writeDebouncer: Task<Void, Never>?` stored on the store and marked `@ObservationIgnored` — internal cancellation token, not part of the observable surface.
- Mutation callsites migrated to `scheduleWrite`: `ProfileStore.toggleProfile`/`reorder`/`deleteProfile`, `SidebarView` (context-menu toggle + row toggle), `ProfileDetailView` (profile toggle, record `isEnabled` toggle, `deleteRecords`), `MenuBarView` row toggle, `AddRecordSheet`, `EditRecordSheet`.
- `SidebarView` footer now shows a `ProgressView().controlSize(.small)` next to the "Nuovo profilo" button while `store.isWritingHosts` is true, with help tooltip "Scrittura /etc/hosts in corso…". Chose the sidebar footer over a menu-bar icon swap because the menu-bar status icon is the subject of task 25 — keeping concerns separate.

### Files modified
- `HostFlow/Stores/ProfileStore.swift` — new debounce/flush/immediate API, `lastWriteAt`, `writeDebouncer`.
- `HostFlow/App/ContentView.swift` — imports `AppKit`, observes `NSApplication.willTerminateNotification` → `flushPendingWrite`.
- `HostFlow/Views/Sidebar/SidebarView.swift` — `scheduleWrite` callsites + ProgressView in footer.
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `scheduleWrite` on profile toggle, record toggle, deleteRecords.
- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift`, `EditRecordSheet.swift` — `scheduleWrite` after insert/edit.
- `HostFlow/Views/MenuBar/MenuBarView.swift` — `scheduleWrite` on profile toggle.

## [2026-05-09] — Hosts write atomic — rollback on error + alert with retry + helper file log

**Type:** feature

### Context
Task `.task/features/21-hosts-write-atomic.md`. The atomic backup-then-rename pipeline was already in place in `HelperService.performWrite`; this entry covers the three gaps surfaced when re-reading the spec against the implementation.

### Changes
- `HelperService.performWrite` now wraps the write/setAttributes/replaceItem sequence in a `do/catch` that removes the leftover `/etc/hosts.hostflow.tmp` if any step after creation fails. Before, the tmp was deleted only *before* the write, so a mid-pipeline failure (e.g. setAttributes denied, replaceItem failing) left a stray tmp file behind. The original `/etc/hosts` was already safe — `replaceItemAt` is the last operation — but the cleanup now matches the spec's "rollback (delete tmp, file originale intatto)".
- New error file log in `HelperService`: on a failed `writeHosts` the helper appends an ISO8601-stamped `ERROR` line to `/Library/Logs/HostFlow/helper.log`. The directory is created on demand and the file is chmod 644 on first write so the user can `tail` it without sudo.
  - **Deviation from spec**: the task says `~/Library/Logs/HostFlow/helper.log`, but the helper runs as root and `~` resolves to `/var/root/Library/Logs/...` — unreadable to the user without sudo, defeating the purpose. `/Library/Logs/HostFlow/helper.log` is the macOS convention for system-daemon logs and is reachable by the user.
  - Level is errors-only (info paths still go to `os_log`), per user choice.
- `ProfileStore.lastWriteError` dropped its `private(set)` so the `ContentView` alert can clear it on dismiss without a dedicated method.
- `ContentView` now binds an `.alert` to `store.lastWriteError`. Title: "Errore di scrittura /etc/hosts". Buttons: "Riprova" (re-runs `store.writeHosts(context:)` with the current profiles) and "Annulla" (cancel role, clears the error). Uses `presenting:` so the message renders the actual error text.

### Files modified
- `HostFlow/Helper/HelperService.swift` — rollback-on-error in `performWrite`; new `appendErrorLog` static helper; `writeHosts` calls it from the catch alongside `os_log`.
- `HostFlow/Stores/ProfileStore.swift` — `lastWriteError` is now publicly settable so the alert binding can clear it.
- `HostFlow/App/ContentView.swift` — added `.alert` modifier with retry/cancel actions on the existing body.

## [2026-05-09] — Hosts authorization — HelperStatus + AppSettings exposure + uninstall confirm

**Type:** feature

### Changes
- New `HelperStatus` enum (`.notInstalled`, `.installed`, `.error(Error)`) in `HelperInstaller.swift`. Replaces the bare `isInstalled: Bool` as the canonical state, while `isInstalled` is kept as a derived convenience.
- `HelperInstaller` is now a singleton (`.shared`) with `@Observable` `status`. `install()`/`uninstall()` mutate `status` on success/failure (`.error` carries the thrown error). New `refreshStatus()` re-checks filesystem on demand.
- `AppSettings` exposes `helperInstaller` and a derived `helperStatus`, so the UI can read the helper state through the same store it already injects.
- `ContentView`, `HelperSettingsSection` and `ProfileStore.writeHosts` migrated to the shared singleton (no more local `HelperInstaller()` instances). `ProfileStore.writeHosts` now calls `refreshStatus()` before checking, so the onboarding sheet triggers correctly even after an external uninstall.
- `HelperSettingsSection` rewritten to switch on `HelperStatus` for the label/button, and to gate uninstall behind a native `.confirmationDialog` ("Disinstallare il componente di sistema?") — prevents an accidental admin prompt + helper removal.
- `.requiresApproval` case explicitly **not** added: it belongs to `SMAppService.daemon` flow which Host Flow does not use (no Apple Developer Team ID). The osascript install path either succeeds, is cancelled by the user, or errors — there is no third "approval pending" state to model.

### Files touched
- `HostFlow/Helpers/HelperInstaller.swift` — `HelperStatus` enum, singleton, status mutations.
- `HostFlow/Stores/AppSettings.swift` — `helperInstaller`/`helperStatus` exposure.
- `HostFlow/Stores/ProfileStore.swift` — singleton + refreshStatus before write check.
- `HostFlow/App/ContentView.swift` — installer pulled from `AppSettings`, dropped local `@State`.
- `HostFlow/Views/Settings/HelperSettingsSection.swift` — status-driven UI + uninstall confirmation dialog.

## [2026-05-08] — Privileged helper — switch from CDHash to binary SHA-256 verification

**Type:** bugfix

### Changes
- **Root cause of the bug**: the previous CDHash-based verification was structurally broken. The post-build sign script ran *before* Xcode's final codesign phase. Xcode's final sign sealed the just-written manifest into a fresh CodeResources hash, so the CDHash stamped in the binary at runtime never matched the CDHash recorded in the manifest. End-to-end Release tests showed the daemon receiving callers with one CDHash while the manifest contained another, causing every call to be rejected silently.
- **Fix**: hash only the main executable (`Contents/MacOS/<CFBundleExecutable>`) with SHA-256 instead of the bundle's CDHash. The executable's bytes are stable once codesign has stamped it, so writing the manifest into `Contents/Resources/` afterwards does not change the hash. The chicken-and-egg dependency between manifest content and bundle CDHash disappears.
- New `Scripts/build-release.sh` end-to-end wrapper: runs `xcodegen generate`, `xcodebuild -configuration Release`, ad-hoc-signs the bundle if Xcode skipped codesign (Automatic signing without a Team ID does so in Release), then invokes `Scripts/sign-manifest.sh`. Replaces the broken `postBuildScripts` "Sign CDHash manifest" entry, which was the wrong place architecturally — Xcode's codesign always runs after user phases.
- `Scripts/sign-manifest.sh` rewritten: reads `CFBundleExecutable` from `Info.plist`, computes `shasum -a 256` of the executable, writes `binary-hash-manifest.json` (`{"version":1,"binaryHashes":["<sha256>"]}`) and an Ed25519 detached signature alongside it. Renamed manifest from `cdhash-manifest.json` to `binary-hash-manifest.json` to make the new semantics explicit. Removed the inline ad-hoc sign step (it now lives in `build-release.sh` to keep `sign-manifest.sh` purely about manifest signing).
- `HostFlow/Helper/CallerVerification.swift` rewritten: removed `extractCDHash` (PID → SecCode → `kSecCodeInfoUnique`); new `sha256OfMainExecutable(bundleURL:)` reads `Contents/Info.plist` for `CFBundleExecutable` and computes `CryptoKit.SHA256.hash` over the executable bytes. `Manifest` Decodable struct now has `binaryHashes` instead of `cdhashes`.
- `HostFlow/project.yml`: dropped the `Sign CDHash manifest` post-build script entry.
- New invariant documented in `docs/helper.md` and enforced by build-release.sh's contract: never run `codesign --force` on the produced `.app` afterwards. Re-signing rewrites the executable's embedded signature blob, changing the SHA-256 and invalidating the manifest. If a fix is needed, run `build-release.sh` end-to-end again.
- Trade-off acknowledged: the hash now covers only the executable, not Info.plist / Resources / Frameworks. Acceptable for Host Flow because the bundle does not load runtime-driven configuration or plug-ins. Discipline note added to `docs/helper.md` §5.4 — when localisation or other Resources-driven features get added, their values must never feed security-critical code paths (paths, shell commands, URLs, AppleScript inputs).

### Files modified
- `Scripts/sign-manifest.sh` — full rewrite around binary SHA-256 + new manifest field name
- `Scripts/build-release.sh` — new end-to-end Release build wrapper
- `HostFlow/Helper/CallerVerification.swift` — replaced CDHash extraction with executable SHA-256 hashing
- `HostFlow/project.yml` — removed broken postBuildScripts entry
- `docs/helper.md` — §5.2 (scheme), §5.3 (threat table), §5.4 (added bundle-integrity caveat + Resources discipline note), §9 (build flow), §10 (failure modes), §11 (file map), §12 (glossary)

## [2026-05-08] — Privileged helper — technical documentation

**Type:** chore

### Changes
- New `docs/helper.md` with end-to-end documentation of the privileged helper subsystem: architecture overview, two-binary build layout, XPC protocol design, connection lifecycle on the client side, full caller-verification flow (PID → SecCode → CDHash → Ed25519 manifest), threat-model table, install/uninstall via `osascript with administrator privileges`, atomic write semantics, build & release procedure including key rotation, failure-mode table, file map, and a glossary covering CDHash / SecCode / Mach service / audit token / Ed25519 / launchctl
- Documents the explicit security trade-offs taken by strategy B2: no Apple Developer Team ID, sandbox disabled on the GUI app, PID lookup vs `auditToken` and why the second-stage CDHash check makes the TOCTOU window irrelevant, DEBUG bypass rationale

### Files modified
- `docs/helper.md` — new

## [2026-05-08] — Privileged helper — XPC client + onboarding UI (sub-task d)

**Type:** feature

### Changes
- New `HostsXPCClient` (`@Observable` singleton) wraps `NSXPCConnection(machServiceName: "com.colilab.hostflow.helper", options: .privileged)`; `invalidationHandler` and `interruptionHandler` both clear the cached connection so the next call lazily reconnects. The `writeHosts(_:)` method bridges the Obj-C reply-block API to `async throws` via `withCheckedThrowingContinuation`
- `HostsFileManager.write(profiles:)` is now `async throws` and delegates to `HostsXPCClient.shared.writeHosts(_:)` instead of writing `/etc/hosts` directly. The previous direct write path is removed
- `ProfileStore.writeHosts(context:)` keeps its synchronous fire-and-forget signature so existing call sites (sidebar/menubar/edit sheets) don't need updating; internally it spawns a `Task { @MainActor }` that drives the async write and surfaces failures via `lastWriteError`
- Pre-flight in `ProfileStore.writeHosts`: if `HelperInstaller().isInstalled == false`, sets a new `helperMissing: Bool` flag and skips the write entirely. ContentView observes this via `@Bindable` and presents `HelperOnboardingSheet` as a modal sheet
- New `HelperOnboardingSheet` (Onboarding folder) explains the one-time admin prompt, calls `HelperInstaller.install()` on confirm, and re-triggers the original write on success
- New `HelperSettingsSection` in Settings exposes "Installato / Non installato" state plus Install/Uninstall buttons with progress + inline error display
- Both UI surfaces (onboarding + settings) drive the same `HelperInstaller`, so installing from Settings dismisses the onboarding sheet on next read

### Files modified
- `HostFlow/Helpers/HostsXPCClient.swift` — new XPC client singleton with async-await bridge
- `HostFlow/Helpers/HostsFileManager.swift` — `write(profiles:)` now async, routes through XPC
- `HostFlow/Stores/ProfileStore.swift` — adds `helperMissing` flag and pre-flight; write becomes Task-driven
- `HostFlow/App/ContentView.swift` — sheet presentation for onboarding bound to `store.helperMissing`
- `HostFlow/Views/Onboarding/HelperOnboardingSheet.swift` — new modal flow
- `HostFlow/Views/Settings/HelperSettingsSection.swift` — new "Componente di sistema" Settings section
- `HostFlow/Views/Settings/SettingsView.swift` — wires the new section into the Settings form

## [2026-05-08] — Privileged helper — installer + atomic write (sub-task c)

**Type:** feature

### Changes
- New `HelperInstaller` (`@Observable`) in `HostFlow/Helpers/`: `install()` copies the embedded helper binary to `/Library/PrivilegedHelperTools/` and the launchd plist to `/Library/LaunchDaemons/`, applies `chown root:wheel` + `chmod` (755 on the binary, 644 on the plist), then `launchctl bootout` (best-effort) followed by `launchctl bootstrap system`; `uninstall()` runs `bootout` and removes both files
- Privileged execution uses `osascript -e 'do shell script ... with administrator privileges'` instead of the deprecated `AuthorizationExecuteWithPrivileges` — same UX (native admin prompt) but no SPI; the script is built as a single bash blob, escaped, and passed via `Process` with stdout/stderr captured for diagnostics
- `isInstalled` now checks both the daemon plist *and* the helper binary on disk (either missing means re-install)
- App entitlements: `com.apple.security.app-sandbox` set to `false`. `osascript with administrator privileges` cannot be spawned from a sandboxed process; this is the documented architectural trade-off of strategy B2 (no Apple Developer Team ID, install custom via launchctl)
- `HelperService.writeHosts` now performs the real atomic write as root:
  - copies the existing `/etc/hosts` to `/etc/hosts.hostflow.bak` (overwriting any prior backup)
  - writes the new content to `/etc/hosts.hostflow.tmp` via `Data.write(options: .atomic)`
  - applies `posixPermissions: 0o644`, `ownerAccountID: 0`, `groupOwnerAccountID: 0` on the tmp file so the final `/etc/hosts` ends up owned by `root:wheel`
  - `FileManager.replaceItemAt` swaps tmp → `/etc/hosts` atomically (backed by the `rename(2)` syscall, so concurrent readers always see a complete file)
- Logging via `os_log` with subsystem `com.colilab.hostflow.helper`, category `service` — visible in Console.app filtered by subsystem

### Files modified
- `HostFlow/Helpers/HelperInstaller.swift` — new install/uninstall flow via osascript
- `HostFlow/Helper/HelperService.swift` — real atomic write replacing the previous no-op stub
- `HostFlow/Resources/HostFlow.entitlements` — sandbox disabled; removed obsolete `/etc/hosts` temporary exception (writes go through the helper now)
- `HostFlow/project.yml` — entitlements properties updated to match

## [2026-05-08] — Privileged helper — Ed25519 manifest signing + caller verification (sub-task b)

**Type:** feature

### Changes
- `Scripts/make-keys.sh` generates an Ed25519 keypair via `openssl genpkey -algorithm ed25519` and prints the 32-byte raw public key as hex for embedding in source; refuses to overwrite an existing private key
- `Scripts/sign-manifest.sh` extracts the CDHash from a signed `.app` bundle via `codesign -dvvv`, writes `Contents/Resources/cdhash-manifest.json` (`{"version":1,"cdhashes":[...]}`) and an Ed25519 detached signature `cdhash-manifest.json.sig` using `openssl pkeyutl -sign -rawin`
- `.gitignore` now excludes `*.pem` and `Scripts/keys/` so the private key cannot be committed accidentally; the user keeps the private key offline (1Password / encrypted external disk)
- New helper sources: `AuthorizedKeys.swift` (public key as hex constant + `Data(hex:)` decoder), `HelperError.swift` (typed errors `unauthorizedCaller` / `manifestMissing` / `manifestInvalid` / `writeFailed`, conforms to `LocalizedError` and `CustomNSError` for clean propagation across XPC), `CallerVerification.swift`
- `CallerVerification` resolves the caller's `SecCode` via `kSecGuestAttributePid` (NOT `kSecGuestAttributeAudit` — `NSXPCConnection.auditToken` is private API; PID lookup is safe here because the CDHash check downstream is content-based, not identity-based), extracts the CDHash with `SecCodeCopySigningInformation` + `kSecCodeInfoUnique`, locates the caller's bundle URL with `SecCodeCopyPath`, then verifies the manifest signature against `AuthorizedKeys.publicKeyData` using `Curve25519.Signing.PublicKey.isValidSignature`, and finally checks the caller CDHash is whitelisted in the manifest
- `#if DEBUG` short-circuits the verification entirely (per task decision: full bypass in Debug, no dev keypair) so local builds work without a private key on disk
- `HelperListenerDelegate.listener(_:shouldAcceptNewConnection:)` runs `CallerVerification.verify()` and refuses the connection on failure, logging via `NSLog`
- New post-build script on the `HostFlow` target: skips signing in Debug; in Release fails the build if `HOSTFLOW_PRIVATE_KEY` env var is unset, otherwise invokes `Scripts/sign-manifest.sh`
- Public key currently a 32-byte zero placeholder — must be replaced by the output of `Scripts/make-keys.sh` before the first Release build

### Files modified
- `Scripts/make-keys.sh` — new keypair-generation script (Ed25519 via openssl)
- `Scripts/sign-manifest.sh` — new manifest signing script
- `.gitignore` — added `*.pem` and `Scripts/keys/`
- `HostFlow/Helper/AuthorizedKeys.swift` — new public-key embedding
- `HostFlow/Helper/HelperError.swift` — new typed errors
- `HostFlow/Helper/CallerVerification.swift` — new SecCode + Ed25519 verification flow
- `HostFlow/Helper/HelperListenerDelegate.swift` — invokes `CallerVerification.verify()` and rejects unauthorized connections
- `HostFlow/project.yml` — new "Sign CDHash manifest" post-build script on `HostFlow`

## [2026-05-08] — Privileged helper (XPC) — scaffolding (sub-task a)

**Type:** feature

### Changes
- Added new `HostFlowHelper` target to `project.yml` (Command Line Tool, macOS 14, bundle id `com.colilab.hostflow.helper`)
- Introduced shared `Shared/` source folder compiled into both `HostFlow` and `HostFlowHelper` targets, hosting the `@objc HostFlowHelperProtocol` (XPC interface) and `HostFlowHelperConstants.machServiceName`
- Helper skeleton: `main.swift` configures `NSXPCListener(machServiceName:)`, `HelperListenerDelegate` accepts connections and exports `HostFlowHelperProtocol`, `HelperService.writeHosts` is currently a no-op stub returning success
- Launchd plist template at `Helper/Resources/com.colilab.hostflow.helper.plist` declares the mach service, root user, and points `ProgramArguments` to `/Library/PrivilegedHelperTools/com.colilab.hostflow.helper` (final installed path)
- Embedding pipeline in the app bundle: helper binary is copied to `HostFlow.app/Contents/Library/LaunchDaemons/` via xcodegen `dependencies.copy` (destination `wrapper`, subpath `Contents/Library/LaunchDaemons`); plist copied alongside via a postBuildScript (xcodegen silently dropped the `.plist` resource entry, so a script phase was the reliable workaround)
- Both targets compile clean with ad-hoc signing; final bundle contains both `com.colilab.hostflow.helper` binary and its plist under `Contents/Library/LaunchDaemons/`
- No real `/etc/hosts` write logic, no caller verification, no installer — those remain in sub-tasks b, c, d

### Files modified
- `HostFlow/project.yml` — new `HostFlowHelper` target, `Shared/` source path on app target, dependency embed + postBuildScript for plist
- `HostFlow/Shared/HostFlowHelperProtocol.swift` — new shared XPC protocol + mach service constant
- `HostFlow/Helper/main.swift` — listener bootstrap
- `HostFlow/Helper/HelperListenerDelegate.swift` — `NSXPCListenerDelegate` exporting the interface
- `HostFlow/Helper/HelperService.swift` — stub `writeHosts` implementation
- `HostFlow/Helper/Resources/com.colilab.hostflow.helper.plist` — launchd plist template

## [2026-05-08] — Untrack xcuserdata files

**Type:** chore

### Changes
- Removed `xcuserdata` files from git tracking; they had been committed before the `.gitignore` rules were added, so the existing ignore patterns had no effect on already-tracked paths
- Files remain on disk locally; future changes will be ignored by the existing `*.xcodeproj/xcuserdata/` and `*.xcworkspace/xcuserdata/` rules

### Files modified
- `HostFlow/HostFlow.xcodeproj/project.xcworkspace/xcuserdata/luca.xcuserdatad/UserInterfaceState.xcuserstate` — untracked
- `HostFlow/HostFlow.xcodeproj/xcuserdata/luca.xcuserdatad/xcschemes/xcschememanagement.plist` — untracked
- `HostFlow/HostFlow.xcodeproj/xcuserdata/acolinucci.xcuserdatad/xcschemes/xcschememanagement.plist` — untracked

## [2026-05-08] — Record — Duplicate (ip, hostname) pair warning

**Type:** feature

### Changes
- Added `@Query` for all profiles to `ProfileDetailView` so the detail can reason about cross-profile state
- Added `RecordPair` `Hashable` (lowercased ip + hostname) and computed `duplicatedPairs: Set<RecordPair>` — counts the (ip, hostname) pair across this profile's records (any state) plus enabled records of other active profiles; entries with count > 1 are flagged
- Pair-based detection avoids false positives like the standard loopback `::1 localhost` + `127.0.0.1 localhost` — different IPs for the same hostname are NOT considered duplicates
- Hostname column in the records Table now wraps the `Text` in an `HStack` and shows an orange `exclamationmark.triangle.fill` SF Symbol with `.help` tooltip "Record duplicato — stessa coppia IP/hostname presente più volte" whenever the row's pair is in the duplicate set
- Validation (blocking) on IP / hostname during add and edit was already covered by tasks 03 + (revised) modal Edit; this task only adds the non-blocking duplicate awareness

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `@Query allProfiles`, `RecordPair` + `duplicatedPairs` computed, warning icon in Hostname column

## [2026-05-08] — Record edit — Modal-only with explicit Save / Cancel

**Type:** refactor

### Changes
- Rolled back the double-click inline edit on IP / Hostname Table cells (task 14): on validation failure the cell stayed open with stale draft text, on click-out the change appeared "saved" while the model was actually unchanged — confusing UX
- Removed `CellAddress`, `editingCell`, `draftValue`, `focusedCell`, `editableCell(...)`, `startEdit/commitEdit/cancelEdit`
- IP / Hostname columns are now plain `Text` views again (with `.opacity(0.5)` for disabled records preserved from task 15)
- Context menu in records Table extended with **"Modifica"** entry (visible only when a single record is selected, disabled when profile is read-only) — opens the existing `EditRecordSheet` modal
- `EditRecordSheet` refactored to use a **draft buffer** (`@State ip`, `@State hostname` initialised from the record) so edits no longer mutate the SwiftData object during typing
- Modal now exposes explicit **"Annulla"** (cancel — discards changes) and **"Salva"** (.borderedProminent, disabled while invalid) buttons instead of the previous single "Chiudi"
- Inline error message + Italian labels + `prompt:` placeholders + `@FocusState` autofocus on IP — consistent with `AddRecordSheet`

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — removed inline-edit infrastructure, plain Text columns, "Modifica" in context menu
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — draft buffer + Annulla / Salva buttons + autofocus

## [2026-05-07] — Record — Search empty state

**Type:** feature

### Changes
- `ProfileDetailView` body now distinguishes three cases: profile with no records, search active with no matches, normal records list
- For the search-no-match case, uses native `ContentUnavailableView.search(text:)` which renders the standard macOS "No Results" view with the current query
- Search bar / filtering / clear button were already in place from the earlier `HSplitView` refactor — this task added only the empty state branch

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — three-way conditional with `ContentUnavailableView.search` branch

## [2026-05-07] — Record delete with multi-select

**Type:** feature

### Changes

- Replaced individual delete buttons with selection-based deletion following macOS conventions
- Added multi-select support (Cmd+click) for batch record deletion
- Added context menu with "Elimina" option on selected records
- Added Delete key support to remove selected records
- Removed the actions column (pencil and trash buttons) - edit is now via double-click, delete via context menu or Delete key
- Delete operations respect read-only profile guard and trigger hosts file write

### Files modified

- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — added multi-select state, context menu, Delete key handler, removed actions column

## [2026-05-07] — Record toggle visual feedback

**Type:** feature

### Changes

- Enhanced visual feedback for disabled host records by adding reduced opacity (0.5) in addition to the existing secondary color
- Disabled records now display with both secondary foreground color and 50% opacity for clearer visual distinction following macOS conventions
- Visual feedback applies to both IP and hostname columns in the records table

### Files modified

- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — added `.opacity(record.isEnabled ? 1.0 : 0.5)` modifier to text cells

## [2026-05-07] — Record — Inline edit IP / hostname

**Type:** feature

### Changes
- Double-clicking an IP or Hostname cell in the records `Table` swaps the `Text` for an inline `TextField` driven by `@FocusState`-managed focus
- Added `CellAddress` `Hashable` struct (recordID + field) to track which cell is being edited
- Return on the IP cell commits the value and advances focus to the Hostname cell of the same row; Return on Hostname commits and exits
- Tab key handled via `.onKeyPress(.tab)` for the same advance/close behaviour
- Esc cancels (`.onExitCommand`) — value reverts
- Validation per field via `HostValidator.isValidIP` / `isValidHostname` on commit; failure shows a red `RoundedRectangle` overlay border on the editing cell, no save, edit stays open until the user fixes or cancels
- Read-only profiles: double-click is a no-op
- Successful commit triggers `writeHosts` so `/etc/hosts` reflects the change immediately for active profiles
- The modal `EditRecordSheet` (pencil button) is preserved alongside as an alternative entry point

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `CellAddress` struct, editing state + `@FocusState`, `editableCell(...)` helper, `startEdit/commitEdit/cancelEdit`, IP/Hostname columns updated to use the editable cell

## [2026-05-07] — Record — Add record polish

**Type:** feature

### Changes

- `AddRecordSheet`: switched the IP/hostname field labels to Italian (`"Indirizzo IP"`, `"Hostname"`) and added inline placeholders via `prompt:` (`"127.0.0.1"` and `"example.local"`)
- Added `@FocusState`-driven autofocus on the IP field when the sheet opens
- Most other checklist items for this task were already in place from earlier work (toolbar `+`, sheet wiring, validation + disable, append + writeHosts, readonly guard) — this task just polished the input UX

### Files modified

- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — `Field` focus enum, prompts, autofocus

## [2026-05-07] — Sidebar row — Tight name truncation

**Type:** bugfix

### Changes

- Profile name in sidebar rows was truncating with ellipsis well before reaching the toggle, leaving a noticeable empty gap
- Root cause: `Toggle` with an `EmptyView()` label still reserved horizontal space for the invisible label slot; combined with a missing outer width constraint, the row never offered the full available width to the name `Text`
- Added `.labelsHidden()` on the profile `Toggle` so it occupies only the actual switch width
- Replaced the inner-HStack-with-frame trick with a flat HStack: `Text/TextField` → `Lock?` (adjacent to the name) → `Spacer(minLength: 0)` → `Toggle`
- Outer HStack now `.frame(maxWidth: .infinity)` so the row claims full sidebar width and the `Spacer(minLength: 0)` only takes up actual leftover space — name truncates only when the row is genuinely too narrow

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `ProfileRowView` layout: `.labelsHidden()` on Toggle, flat HStack with `Spacer(minLength: 0)`, outer `.frame(maxWidth: .infinity)`

## [2026-05-07] — Sidebar — Remove double-click inline rename trigger

**Type:** bugfix

### Changes

- Removed the double-click `TapGesture` from the profile name `Text` in `ProfileRowView` — it was preventing single-click row selection from reaching the List
- Inline rename UI (Text ↔ TextField transition driven by `editingProfileID`) is preserved; the rename flow is now triggered exclusively from the "Rinomina" context-menu item (introduced in task 11)
- Single click on the row now selects normally on macOS

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — removed `.simultaneousGesture(TapGesture(count: 2))` on profile name

## [2026-05-07] — Sidebar — Drag & drop reorder

**Type:** feature

### Changes

- Sidebar `List` converted to `List(selection:) { ForEach(profiles).onMove { ... } }` to enable native drag & drop reordering of profiles
- `.moveDisabled(profile.isReadOnly)` on each row prevents the Default profile from being dragged
- `onMove` rejects any drop with `destination == 0` so no profile can take the Default's first-position slot
- Reordering persists via the existing `ProfileStore.reorder(_:context:)`, which now also triggers `writeHosts(context:)` because per-profile sub-headers in `/etc/hosts` are sorted by `order`

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — List → ForEach + onMove + moveDisabled
- `HostFlow/Stores/ProfileStore.swift` — `reorder` now triggers `writeHosts`

## [2026-05-07] — Sidebar — Full context menu (Rinomina / Duplica / Elimina / Toggle)

**Type:** feature

### Changes

- Sidebar context menu extended: "Rinomina", "Duplica", "Elimina" (destructive), divider, "Attiva"/"Disattiva" (dynamic label)
- "Rinomina" sets `editingProfileID` and reuses the inline-rename flow built in task 09
- "Duplica" calls `ProfileStore.duplicate(_:context:)` and auto-selects the copy
- "Attiva"/"Disattiva" toggles `isActive` and triggers `writeHosts`
- Read-only guard applied to Rinomina, Elimina and Toggle (consistent with the global "Default profile is fully locked" decision); Duplica is always available since it produces an editable copy
- Added `ProfileStore.duplicate(_:context:)` — generates a unique name via `uniqueDuplicateName(base:among:)` (`<name> (copia)`, `<name> (copia 2)`, ... case-insensitive), copies all records with fresh UUIDs preserving each record's `isEnabled`, sets `isActive = false`, `isReadOnly = false`, `order = max + 1`

### Files modified

- `HostFlow/Stores/ProfileStore.swift` — `duplicate(_:context:)` + `uniqueDuplicateName` helper
- `HostFlow/Views/Sidebar/SidebarView.swift` — extended `.contextMenu` with all items

## [2026-05-07] — Sidebar row layout — name left, toggle right

**Type:** refactor

### Changes

- `ProfileRowView` reordered: profile name (with lock icon when read-only) on the left, switch toggle pinned to the right via `Spacer(minLength: 8)`
- Name truncates with ellipsis (`.lineLimit(1)` + `.truncationMode(.tail)`) when sidebar is narrow, lock icon and toggle remain visible

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `ProfileRowView` layout reorder

## [2026-05-07] — Sidebar — Delete profile

**Type:** feature

### Changes

- Added `.contextMenu` on each sidebar row with a destructive "Elimina" item — disabled when the profile is read-only
- Added `.onDeleteCommand` on the sidebar `List` so the Delete key on a selected non-readonly profile triggers the same flow
- Both paths set `profileToDelete: Profile?`, which presents a `.confirmationDialog`: title "Eliminare profilo \"X\"?", message about cascade & irreversibility, destructive "Elimina" + cancel "Annulla"
- After confirmed deletion, auto-selects the next profile by `order` (or the previous one if the deleted was the last, or `nil` if it was the only one)
- Cascade delete of related `HostRecord`s already guaranteed by `Profile.records` `@Relationship(deleteRule: .cascade)` — no extra logic needed
- `ProfileStore.deleteProfile` already calls `writeHosts(context:)` → no change

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — context menu, Delete shortcut, confirmation dialog, deletion helper with auto-select

## [2026-05-07] — Fill panes vertically in HSplitView

**Type:** bugfix

### Changes

- Selecting a profile with no records caused the whole window content (both panes) to collapse to its intrinsic height and center vertically — `HSplitView` was not being asked to fill its host
- Added `.frame(maxHeight: .infinity)` to `SidebarView`'s root VStack and to `ProfileDetailView`'s root VStack
- The empty-state `ContentUnavailableView` instances (in `ProfileDetailView` and the no-selection branch in `ContentView`) now claim `maxWidth/maxHeight: .infinity` so they fill the pane

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `.frame(maxHeight: .infinity)` on root
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — fills + ContentUnavailableView fill
- `HostFlow/App/ContentView.swift` — right pane Group fills

## [2026-05-07] — Sidebar — Inline profile rename

**Type:** feature

### Changes

- Double-clicking a sidebar profile name now switches it to a `TextField` with autofocus, blending into the row via `.textFieldStyle(.plain)`
- Enter commits, Esc reverts, click-outside (blur) commits as well
- Empty draft or unchanged name → silent revert
- Duplicate name (case-insensitive, excluding self) → silent revert (the brief red-flash warning was removed because it was nearly invisible on the selected-row blue background)
- Read-only profiles: double-click is a no-op (no editing mode)
- Editing state lives at `SidebarView` level (`editingProfileID: UUID?`) so only one row is editable at a time; rows receive `isEditing`/`existingNames`/`onBeginEdit`/`onEndEdit` props

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — added inline rename in `ProfileRowView` + parent editing state

## [2026-05-07] — Fixed two-pane layout via HSplitView

**Type:** refactor

### Changes

- Replaced `NavigationSplitView` with `HSplitView` in `ContentView`
- Sidebar and detail are now both permanently visible — no collapse toggle, no show/hide animation
- Native draggable divider preserved between the two panes for manual resize
- Sidebar pane: `minWidth: 180, idealWidth: 220, maxWidth: 320`; detail pane: `minWidth: 400`

### Files modified

- `HostFlow/App/ContentView.swift` — NavigationSplitView → HSplitView with frame constraints

## [2026-05-07] — Sidebar — Add profile sheet

**Type:** feature

### Changes

- New `AddProfileSheet` with TextField + autofocus, live validation (empty + case-insensitive duplicate), inline red error, and Submit-on-Return
- "Crea" button disabled while invalid
- `ProfileStore.addProfile(name:context:)` now returns the created `Profile` (`@discardableResult`) so callers can auto-select it
- `SidebarView` replaces the previous `.alert` with the new sheet, then auto-selects the freshly created profile via `selectedProfile`
- Regenerated Xcode project to include the new sheet

### Files modified

- `HostFlow/Views/Sidebar/AddProfileSheet.swift` — new file: sheet with validation
- `HostFlow/Views/Sidebar/SidebarView.swift` — alert → sheet, auto-select on create
- `HostFlow/Stores/ProfileStore.swift` — `addProfile` returns the created profile
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Hosts block builder with warning and per-profile headers

**Type:** feature

### Changes

- `HostsFileManager.buildBlock` now emits a "DO NOT EDIT MANUALLY" warning (2 lines) immediately after the start marker
- Each active profile is preceded by a `# --- <Profile Name> ---` sub-header, separated by a blank line
- Profiles sorted by `order` before serialization for deterministic output
- Record formatting uses single space between IP and hostname (was tab) for broader tool compatibility
- Disabled records still serialized as `# <ip> <hostname>`; inactive profiles fully omitted

### Files modified

- `HostFlow/Helpers/HostsFileManager.swift` — `buildBlock` rewrite + warning constants

## [2026-05-07] — Enforce read-only on system profile UI

**Type:** bugfix

### Changes

- Extended task `02-data-readonly-flag`: read-only flag now actively disables UI controls instead of being a visual marker only
- `SidebarView.ProfileRowView` — profile `isActive` toggle disabled when `profile.isReadOnly`
- `MenuBarView.MenuBarProfileRow` — profile toggle disabled + lock icon shown next to the name
- `ProfileDetailView` toolbar — profile toggle and "Aggiungi record" button disabled when read-only (with help tooltip)
- `ProfileDetailView` records list — per-record `isEnabled` toggle, edit (pencil), and delete (trash) buttons all disabled when the parent profile is read-only
- Anticipates guards from upcoming tasks 13/15/16 — those tasks now find their checks already implemented

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `.disabled` on isActive toggle
- `HostFlow/Views/MenuBar/MenuBarView.swift` — `.disabled` on isActive toggle + lock badge
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `.disabled` on toolbar toggle, add button, record toggle, edit/delete buttons

## [2026-05-07] — Default profile seed from /etc/hosts

**Type:** feature

### Changes

- Added `HostsFileParser` helper with `ParsedHostRecord` struct, `parseSystemHosts()` (reads `/etc/hosts` excluding the Host Flow managed block), and `parse(_:)` for arbitrary content
- Parser handles commented records (`# 127.0.0.1 localhost` → disabled record), strips trailing inline comments, splits multi-hostname lines into separate records, validates IP and hostname via `HostValidator`
- Added `ProfileStore.seedIfNeeded(context:)` — idempotent, creates the "Default" profile (`isActive=true`, `isReadOnly=true`, `order=0`) populated from `/etc/hosts` on first launch
- Fail-safe: if `/etc/hosts` cannot be read, an empty Default profile is created and a warning is logged — no crash
- Wired `seedIfNeeded` into `ContentView.task` plus an `onChange(of: profiles.count)` that auto-selects the first profile after seeding completes
- Regenerated Xcode project to include the new parser file

### Files modified

- `HostFlow/Helpers/HostsFileParser.swift` — new file: parser + `ParsedHostRecord`
- `HostFlow/Stores/ProfileStore.swift` — `seedIfNeeded(context:)` helper
- `HostFlow/App/ContentView.swift` — seed on appear + reactive selection
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Structured /etc/hosts read

**Type:** feature

### Changes

- Added `HostsFileContent` struct with `preBlock`, `block` (optional), `postBlock` segments
- Added `HostsFileError: LocalizedError` enum (`notReadable`, `malformedBlock`, `encodingFailed`) with Italian messages
- Replaced `HostsFileManager.read() throws -> String` with `read() throws -> HostsFileContent` — parses the managed Host Flow block and returns segmented content
- Tolerant parser: both markers absent → `block = nil`, all content in `preBlock`; one marker present without the other → throws `.malformedBlock`
- Added private `readRaw()` helper used by the existing `write()` path — `write()` will be reworked under task 21

### Files modified

- `HostFlow/Helpers/HostsFileManager.swift` — structured read + content type + error enum

## [2026-05-07] — Profile ordering hardening

**Type:** chore

### Changes

- Fixed `ProfileStore.addProfile` — replaced fragile `count`-based order assignment (which produced duplicates after deletions) with `max(order) + 1`
- Added `ProfileStore.reorder(_:context:)` — accepts an already-ordered profile list and reassigns `order = index`, ready for the upcoming drag-reorder UI
- Verified `@Query(sort: \Profile.order)` already in place in `SidebarView` and `MenuBarView`

### Files modified

- `HostFlow/Stores/ProfileStore.swift` — `addProfile` fix + `reorder` helper

## [2026-05-07] — IP + hostname validation

**Type:** feature

### Changes

- Added `HostValidator` helper with static IPv4/IPv6 validation (via `inet_pton`) and RFC 1123 hostname regex (single-label allowed)
- Added `ValidationError: LocalizedError` enum (`emptyIP`, `invalidIP`, `emptyHostname`, `invalidHostname`) with Italian user-facing messages
- `validateRecord(ip:hostname:)` convenience that trims whitespace and returns the first failure
- Integrated validation in `AddRecordSheet`: "Aggiungi" disabled while invalid, inline red error message; saves trimmed values
- Integrated validation in `EditRecordSheet`: "Chiudi" disabled while invalid, inline red error message; trims on save
- Regenerated Xcode project to include new helper file

### Files modified

- `HostFlow/Helpers/HostValidator.swift` — new file: validators + error enum
- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — validation integration + trim on save
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — validation integration + trim on save
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Profile read-only flag

**Type:** chore

### Changes

- Added `isReadOnly: Bool` field to `Profile` model (default `false`, lightweight SwiftData migration)
- Added computed `isEditable` on `Profile` for use in views
- Added `canEdit(_:)` helper to `ProfileStore`
- `SidebarView.ProfileRowView` shows `lock.fill` SF Symbol next to the profile name when read-only
- Added tooltip "Profilo di sistema — duplica per modificare" on read-only rows
- Build verified: app compiles cleanly with the schema change

### Files modified

- `HostFlow/Models/Profile.swift` — added `isReadOnly` field, init parameter, `isEditable` computed
- `HostFlow/Stores/ProfileStore.swift` — added `canEdit(_:)` helper
- `HostFlow/Views/Sidebar/SidebarView.swift` — lock icon + tooltip on read-only rows

## [2026-05-06] — Xcode Project Scaffolding + MVVM Base Architecture

**Type:** chore

### Changes

- Created `project.yml` for XcodeGen with macOS 14.0+ target, sandbox entitlements, and `/etc/hosts` temporary exception
- Generated `HostFlow.xcodeproj` via `xcodegen generate`
- Defined SwiftData models: `Profile` (@Model, cascade delete) and `HostRecord` (@Model, inverse relationship)
- Implemented `@Observable ProfileStore` with profile CRUD and hosts write trigger
- Implemented `@Observable AppSettings` with appearance mode (persisted to UserDefaults) and launch-at-login via `SMAppService`
- Built `SidebarView` with `List`, per-profile toggle, add profile via Alert
- Built `ProfileDetailView` with SwiftUI `Table`, per-record toggle/edit/delete, search, `AddRecordSheet`, `EditRecordSheet`
- Built `MenuBarView` with per-profile toggles, "Open Host Flow", Settings link, Quit
- Built `SettingsView` with launch-at-login toggle, appearance picker, version info
- Implemented `HostsFileManager` with marker-based block read/write (`# --- Host Flow Start/End ---`)
- Created `ContentView` with `NavigationSplitView` wiring sidebar and detail

### Files modified

- `HostFlow/project.yml` — XcodeGen project definition
- `HostFlow/HostFlow.xcodeproj` — generated Xcode project
- `HostFlow/App/HostFlowApp.swift` — app entry point, 3 scenes, shared ModelContainer
- `HostFlow/App/ContentView.swift` — NavigationSplitView root
- `HostFlow/Models/Profile.swift` — SwiftData model
- `HostFlow/Models/HostRecord.swift` — SwiftData model
- `HostFlow/Stores/ProfileStore.swift` — observable store
- `HostFlow/Stores/AppSettings.swift` — observable settings
- `HostFlow/Views/Sidebar/SidebarView.swift` — sidebar + profile rows
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — record table
- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — add record modal
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — edit record modal
- `HostFlow/Views/MenuBar/MenuBarView.swift` — menu bar popover
- `HostFlow/Views/Settings/SettingsView.swift` — settings form
- `HostFlow/Helpers/HostsFileManager.swift` — hosts file read/write
- `HostFlow/Resources/Info.plist` — app metadata
- `HostFlow/Resources/HostFlow.entitlements` — sandbox + /etc/hosts permission
- `HostFlow/Resources/Assets.xcassets` — app icon placeholder
