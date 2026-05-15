# Plan: Internazionalizzazione (EN + IT) via String Catalog

**Date:** 2026-05-15
**Type:** feature

## Original prompt
> le stringhe di testo ora non sono internazionalizzate. prevedi l'utilizzo della metodologia standard di SwiftUi per l'internazionalizzazione delle stringhe. le lingue da utilizzare sono Inglese ed Italiano

## Summary
Introdurre il supporto i18n nell'app usando lo **String Catalog** (`.xcstrings`) di Xcode 15+, con **inglese come lingua di sviluppo (base)** e **italiano** come traduzione. Tutte le stringhe UI, i messaggi di errore/alert e le voci di `Info.plist` rilevanti per l'utente vengono spostate nel catalogo. Le chiavi seguono uno schema **gerarchico** (es. `sidebar.button.add_profile`). Viene inoltre aggiunto in `SettingsView` un selettore di lingua (System / English / Italiano) che applica un override del locale a runtime via `.environment(\.locale, …)` sulle scene root, senza necessità di riavvio.

## Steps

### 1. Configurazione progetto
1. [ ] Aggiornare `HostFlow/project.yml`: aggiungere `developmentRegion: en` e `knownRegions: [en, it, Base]` a livello di `options` (per `xcodegen`).
2. [ ] Aggiornare `HostFlow/Resources/Info.plist`: impostare `CFBundleDevelopmentRegion = en` e aggiungere `CFBundleLocalizations = [en, it]`.
3. [ ] Rigenerare il progetto Xcode con `Scripts/` (xcodegen) se necessario — verificare che `Resources/` sia incluso nel target.

### 2. Creare i cataloghi stringhe
4. [ ] Creare `HostFlow/Resources/Localizable.xcstrings` con `sourceLanguage: "en"` e tutte le chiavi gerarchiche elencate sotto (sezione **Chiavi**). Popolare sia `en` che `it`.
5. [ ] Creare `HostFlow/Resources/InfoPlist.xcstrings` con localizzazione di:
   - `CFBundleDisplayName` (it: "Host Flow", en: "Host Flow")
   - `CFBundleName`
   - eventuali `NSXxxUsageDescription` se presenti (verificare `Info.plist`).
6. [ ] Aggiungere entrambi i cataloghi al target `HostFlow` in `project.yml` (sotto `sources:` come `path: Resources/Localizable.xcstrings` e `path: Resources/InfoPlist.xcstrings`).

### 3. Refactor delle View — sostituire stringhe letterali con chiavi
Le seguenti View vanno aggiornate. Ogni stringa hardcoded passa a `Text("chiave")`, `Label("chiave", systemImage: …)`, `Button("chiave") { … }`, `.navigationTitle("chiave")`, `TextField("chiave", …)`, ecc. SwiftUI usa `LocalizedStringKey` automaticamente per questi inizializzatori. Per stringhe assemblate dinamicamente (es. in `String(format:)` o variabili `String`) usare `String(localized: "chiave")` o `LocalizedStringResource("chiave")`.

7. [ ] [`HostFlow/App/ContentView.swift`](HostFlow/App/ContentView.swift) — titoli, placeholder empty state.
8. [ ] [`HostFlow/App/HostFlowApp.swift`](HostFlow/App/HostFlowApp.swift) — eventuali label di scene (`Settings`, `MenuBarExtra` label).
9. [ ] [`HostFlow/Views/Sidebar/SidebarView.swift`](HostFlow/Views/Sidebar/SidebarView.swift) — titolo sidebar, tooltip, accessibility label, bottone "+", voce Settings.
10. [ ] [`HostFlow/Views/Sidebar/AddProfileSheet.swift`](HostFlow/Views/Sidebar/AddProfileSheet.swift) — titolo sheet, placeholder, bottoni Save/Cancel.
11. [ ] [`HostFlow/Views/ProfileDetail/ProfileDetailView.swift`](HostFlow/Views/ProfileDetail/ProfileDetailView.swift) — header, intestazioni colonne tabella, empty state, toolbar.
12. [ ] [`HostFlow/Views/ProfileDetail/AddRecordSheet.swift`](HostFlow/Views/ProfileDetail/AddRecordSheet.swift) — placeholder IP/hostname, bottoni.
13. [ ] [`HostFlow/Views/ProfileDetail/EditRecordSheet.swift`](HostFlow/Views/ProfileDetail/EditRecordSheet.swift) — idem.
14. [ ] [`HostFlow/Views/MenuBar/MenuBarView.swift`](HostFlow/Views/MenuBar/MenuBarView.swift) — voci menu, "Apri Host Flow", "Impostazioni…", "Esci".
15. [ ] [`HostFlow/Views/Settings/SettingsView.swift`](HostFlow/Views/Settings/SettingsView.swift) — etichette tab, label "Launch at login", "Appearance", versione app + aggiungere selettore lingua (vedi step 19).
16. [ ] [`HostFlow/Views/Settings/HelperSettingsSection.swift`](HostFlow/Views/Settings/HelperSettingsSection.swift) — testi sezione helper.
17. [ ] [`HostFlow/Views/Onboarding/HelperOnboardingSheet.swift`](HostFlow/Views/Onboarding/HelperOnboardingSheet.swift) — titoli, body, bottoni step.

### 4. Errori e alert
18. [ ] [`HostFlow/Helper/HelperError.swift`](HostFlow/Helper/HelperError.swift) — implementare/aggiornare `errorDescription`/`failureReason` di `LocalizedError` usando `String(localized: "error.helper.xxx")`. Stesso pattern per qualsiasi altro tipo `Error` mostrato all'utente (cercare `.alert`, `Alert(title:` nelle view).

### 5. Selettore lingua in Settings
19. [ ] [`HostFlow/Stores/AppSettings.swift`](HostFlow/Stores/AppSettings.swift) — aggiungere proprietà `preferredLanguage: PreferredLanguage` (enum `.system | .en | .it`) persistita con `@AppStorage("preferredLanguage")`.
20. [ ] In `SettingsView` aggiungere un `Picker` ("settings.language.title") con le 3 opzioni ("settings.language.system", "settings.language.en", "settings.language.it").
21. [ ] [`HostFlow/App/HostFlowApp.swift`](HostFlow/App/HostFlowApp.swift) — applicare `.environment(\.locale, appSettings.resolvedLocale)` su `MainScene`, `MenuBarScene`, `SettingsScene`. `resolvedLocale` ritorna `Locale.current` per `.system` altrimenti `Locale(identifier: "en"|"it")`.

### 6. Seed profili / nomi default
22. [ ] Cercare in [`HostFlow/Stores/ProfileStore.swift`](HostFlow/Stores/ProfileStore.swift) (e altrove) i nomi profilo creati di default. Sostituire la string letterale con `String(localized: "profile.seed.default")` al momento della creazione. **Nota:** una volta salvato in SwiftData il nome è user data e non cambia più al cambio lingua (comportamento atteso).

### 7. Verifica
23. [ ] Build target `HostFlow` — `xcodebuild -project HostFlow/HostFlow.xcodeproj -scheme HostFlow build` (o usare lo script in `Scripts/`).
24. [ ] Avviare l'app, cambiare lingua dal selettore in Settings, verificare che UI principale, menu bar, settings, sheet e alert si aggiornino. Verificare il nome dell'app nel Finder (richiede riavvio per `InfoPlist.xcstrings`).

## Chiavi — schema gerarchico

Convenzione: `<area>.<componente>.<elemento>[.<variante>]`, minuscolo, snake_case.

**Generali**
- `common.button.save`, `common.button.cancel`, `common.button.delete`, `common.button.edit`, `common.button.add`, `common.button.close`, `common.button.ok`
- `common.placeholder.search`

**Sidebar**
- `sidebar.title`
- `sidebar.button.add_profile`
- `sidebar.button.settings`
- `sidebar.empty.title`, `sidebar.empty.description`

**Profili**
- `profile.add.sheet.title`
- `profile.add.field.name.placeholder`
- `profile.detail.empty.title`, `profile.detail.empty.description`
- `profile.detail.toolbar.add_record`
- `profile.detail.column.enabled`, `profile.detail.column.ip`, `profile.detail.column.hostname`, `profile.detail.column.actions`
- `profile.seed.default` ("Default" / "Default")

**Record**
- `record.add.sheet.title`, `record.edit.sheet.title`
- `record.field.ip.placeholder`, `record.field.hostname.placeholder`

**Menu Bar**
- `menubar.item.open_app`
- `menubar.item.settings`
- `menubar.item.quit`
- `menubar.section.profiles`

**Settings**
- `settings.tab.general`, `settings.tab.helper`, `settings.tab.about`
- `settings.toggle.launch_at_login`
- `settings.appearance.title`, `settings.appearance.system`, `settings.appearance.light`, `settings.appearance.dark`
- `settings.language.title`, `settings.language.system`, `settings.language.en`, `settings.language.it`
- `settings.about.version`

**Onboarding helper**
- `onboarding.helper.title`, `onboarding.helper.description`
- `onboarding.helper.button.install`, `onboarding.helper.button.later`

**Errori**
- `error.helper.not_installed`
- `error.helper.authorization_denied`
- `error.helper.xpc_connection_failed`
- `error.hosts.write_failed`
- `error.hosts.read_failed`
- `error.validation.ip_invalid`
- `error.validation.hostname_invalid`

(L'elenco definitivo viene completato durante il refactor file-per-file; ogni nuova stringa segue lo stesso schema.)

## Out of scope
- Localizzazione di log/print interni (rimangono in inglese).
- Pluralizzazione complessa / varianti grammaticali avanzate (introdurre solo se necessario per una stringa specifica durante il refactor).
- Localizzazione delle stringhe interne all'helper XPC che non vengono mai presentate all'utente.
- Aggiunta di lingue oltre EN e IT.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-15

**Resolution:** Added `Localizable.xcstrings` + `InfoPlist.xcstrings` (English source, Italian translation) wired through `project.yml`, refactored all SwiftUI views, errors and stores to use hierarchical localized keys, introduced a `PreferredLanguage` setting with a Settings picker and a `.environment(\.locale, …)` override on every scene for runtime language switching. Build verified.
