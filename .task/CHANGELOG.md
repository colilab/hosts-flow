# Changelog

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
