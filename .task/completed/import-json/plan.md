# Plan: Import JSON con merge / replace

**Date:** 2026-05-15
**Type:** feature
**Ref:** [.task/features/37-import-json.md](.task/features/37-import-json.md)

## Original prompt
> @.task/features/37-import-json.md — Importare un file JSON esportato ripristinando profili e record, con scelta utente tra modalità "merge" o "replace". File picker JSON, validazione schema (version), preview con count, error handling per file corrotto / versione non supportata.

## Summary
Aggiungere import del JSON prodotto da `ExportService`. L'azione attuale "Importa…" in `SettingsView` → Advanced diventa un `Menu` con due voci: "Da file hosts…" (esistente) e "Da JSON…" (nuova). Il flusso JSON: `NSOpenPanel` `.json` → decode con validazione `version` → sheet di preview con conteggio profili/record e `Picker` Merge/Replace → conferma. Replace richiede un secondo `.alert` distruttivo che mostra il numero di profili utente che saranno eliminati. Nessuna scrittura automatica di `/etc/hosts` post-import (i profili importati arrivano inattivi).

## Decisioni prese durante il grilling
- **UI:** il bottone "Importa…" in Advanced diventa un `Menu`: "Da file hosts…" (esistente, da rifattorizzare leggermente) / "Da JSON…" (nuovo flusso).
- **Replace scope:** elimina **solo i profili utente** (`isReadOnly == false`). Il profilo Default resta.
- **Merge:** nomi in collisione → suffisso "(imported)" / "(importato)" (chiave nuova `profile.import.suffix`). Se anche `<name> (imported)` esiste, aggiungere numero progressivo.
- **Post-import:** **nessuna** `writeHosts` (lo schema omette `isActive`: tutti gli importati sono inattivi, quindi nessun cambiamento al blocco gestito).
- **Conferma Replace:** sì, `.alert` distruttivo con conteggio profili eliminati.
- **Preview sheet:** solo conteggi totali ("X profili, Y record"). Niente lista per-profilo o tabella record.
- **Versioning:** solo `ExportPayload.currentVersion = 1` supportata. Versioni superiori → errore "Versione non supportata". Versioni inferiori a 1 (es. 0 o assenti) → "File JSON non valido".

## Steps

### 1. Servizio di parsing JSON
1. [ ] Nuovo file [`HostFlow/Helpers/ImportJSONService.swift`](HostFlow/Helpers/ImportJSONService.swift):
   ```swift
   enum ImportJSONError: LocalizedError {
       case readFailed(String)
       case invalidFormat
       case unsupportedVersion(found: Int, max: Int)
       var errorDescription: String? { ... }   // localizzato
   }

   struct ImportJSONResult: Identifiable {
       let id = UUID()
       let payload: ExportPayload
       var profileCount: Int { payload.profiles.count }
       var recordCount: Int { payload.profiles.reduce(0) { $0 + $1.records.count } }
   }

   enum ImportMode: String, CaseIterable, Identifiable {
       case merge, replace
       var id: String { rawValue }
       var labelKey: LocalizedStringKey {
           switch self { case .merge: "import.json.mode.merge"
                         case .replace: "import.json.mode.replace" }
       }
   }

   enum ImportJSONService {
       static func parseFile(at url: URL) throws -> ImportJSONResult {
           let data: Data
           do { data = try Data(contentsOf: url) }
           catch { throw ImportJSONError.readFailed(error.localizedDescription) }

           let payload: ExportPayload
           do { payload = try JSONDecoder().decode(ExportPayload.self, from: data) }
           catch { throw ImportJSONError.invalidFormat }

           guard payload.version >= 1 else { throw ImportJSONError.invalidFormat }
           guard payload.version <= ExportPayload.currentVersion else {
               throw ImportJSONError.unsupportedVersion(
                   found: payload.version, max: ExportPayload.currentVersion
               )
           }
           return ImportJSONResult(payload: payload)
       }
   }
   ```

### 2. Servizio di applicazione (merge / replace) in ProfileStore
2. [ ] [`HostFlow/Stores/ProfileStore.swift`](HostFlow/Stores/ProfileStore.swift) — aggiungere:
   ```swift
   func userProfileCount(context: ModelContext) -> Int { ... }   // fetch isReadOnly==false

   func applyImport(_ payload: ExportPayload, mode: ImportMode, context: ModelContext) {
       switch mode {
       case .replace:
           let descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.isReadOnly == false })
           for p in (try? context.fetch(descriptor)) ?? [] {
               context.delete(p)
           }
       case .merge:
           break
       }

       let existing = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
       var existingNames = Set(existing.map { $0.name.lowercased() })
       let baseOrder = (existing.map(\.order).max() ?? -1) + 1

       for (idx, source) in payload.profiles.enumerated() {
           let finalName = uniqueImportName(source.name, taken: &existingNames)
           let profile = Profile(name: finalName, order: baseOrder + idx, isReadOnly: false)
           context.insert(profile)
           for record in source.records {
               let r = HostRecord(ip: record.ip, hostname: record.hostname, profile: profile)
               r.isEnabled = record.isEnabled
               context.insert(r)
           }
       }
       try? context.save()
       // No writeHosts: imported profiles arrive isActive=false.
   }

   private func uniqueImportName(_ name: String, taken: inout Set<String>) -> String {
       if !taken.contains(name.lowercased()) {
           taken.insert(name.lowercased())
           return name
       }
       let suffix = String(localized: "profile.import.suffix")  // "%@ (imported)"
       let candidate = String(format: suffix, name)
       if !taken.contains(candidate.lowercased()) {
           taken.insert(candidate.lowercased())
           return candidate
       }
       var i = 2
       let numbered = String(localized: "profile.import.suffix_numbered") // "%1$@ (imported %2$d)"
       while true {
           let next = String(format: numbered, name, i)
           if !taken.contains(next.lowercased()) {
               taken.insert(next.lowercased())
               return next
           }
           i += 1
       }
   }
   ```

### 3. Preview sheet
3. [ ] Nuovo file [`HostFlow/Views/Settings/ImportJSONSheet.swift`](HostFlow/Views/Settings/ImportJSONSheet.swift):
   - Props: `result: ImportJSONResult`, `userProfileCount: Int`, `onConfirm: (ImportMode) -> Void`.
   - `@State mode: ImportMode = .merge`, `@State showReplaceConfirm = false`.
   - Layout (`width: 420`):
     - Title `Text("import.json.sheet.title").font(.headline)`
     - `Text("import.json.count \(profileCount) \(recordCount)")` con formato "%1$d profiles, %2$d records" / "%1$d profili, %2$d record".
     - `Picker("import.json.mode.label", selection: $mode) { ForEach(ImportMode.allCases) { Text($0.labelKey).tag($0) } }.pickerStyle(.segmented)`
     - Caption descrittiva dipendente dalla modalità: "import.json.mode.merge.description" / "import.json.mode.replace.description".
     - HStack: Cancel / Import button.
   - On Import:
     - `.merge` → chiama `onConfirm(.merge)` + `dismiss()`.
     - `.replace` → set `showReplaceConfirm = true`. Non chiude.
   - `.alert("import.json.replace.confirm.title", isPresented: $showReplaceConfirm)`:
     - Message: format con userProfileCount, "import.json.replace.confirm.message"  ("%d existing profiles will be deleted. Continue?").
     - Buttons: Cancel / Delete and import (destructive) → `onConfirm(.replace); dismiss()`.

### 4. Wire in SettingsView
4. [ ] [`HostFlow/Views/Settings/SettingsView.swift`](HostFlow/Views/Settings/SettingsView.swift):
   - Aggiungere stato: `@State private var importJSONResult: ImportJSONResult?`, `@State private var importJSONError: String?`.
   - Sostituire il bottone "Importa…" attuale con un `Menu`:
     ```swift
     Menu {
         Button("settings.advanced.import.hosts") { startImport() }            // esistente
         Button("settings.advanced.import.json")  { startImportJSON() }
     } label: {
         Text("settings.advanced.import.button")
     }
     .menuStyle(.borderlessButton)
     .fixedSize()
     ```
   - `private func startImportJSON()`:
     - `NSOpenPanel()` con `allowedContentTypes = [.json]`, `title = "settings.advanced.import.json.panel.title"`.
     - `panel.begin { ... }`: on `.OK`, prova `ImportJSONService.parseFile(at: url)`. On success → set `importJSONResult`. On error → set `importJSONError = error.localizedDescription`.
   - `.alert("settings.advanced.import.error.title", presenting: importJSONError, ...)` (riuso pattern dell'alert export).
   - `.sheet(item: $importJSONResult)`:
     ```swift
     ImportJSONSheet(
         result: result,
         userProfileCount: userProfileCount()
     ) { mode in
         store.applyImport(result.payload, mode: mode, context: modelContext)
         showHUD("settings.advanced.import.done")
     }
     ```
   - `private func userProfileCount() -> Int`: fetch su `isReadOnly == false`.

### 5. Stringhe localizzate
5. [ ] [`HostFlow/Resources/Localizable.xcstrings`](HostFlow/Resources/Localizable.xcstrings) — nuove chiavi (EN / IT):
   - `settings.advanced.import.hosts` → "From hosts file…" / "Da file hosts…"
   - `settings.advanced.import.json` → "From JSON…" / "Da JSON…"
   - `settings.advanced.import.json.panel.title` → "Import JSON" / "Importa JSON"
   - `import.json.sheet.title` → "Import profiles from JSON" / "Importa profili da JSON"
   - `import.json.count` (format `%1$d profiles, %2$d records`) → "%1$d profiles, %2$d records" / "%1$d profili, %2$d record"
   - `import.json.mode.label` → "Mode" / "Modalità"
   - `import.json.mode.merge` → "Merge" / "Unisci"
   - `import.json.mode.replace` → "Replace" / "Sostituisci"
   - `import.json.mode.merge.description` → "Append imported profiles to the existing ones. Duplicate names get a suffix." / "Aggiungi i profili importati a quelli esistenti. I nomi duplicati ricevono un suffisso."
   - `import.json.mode.replace.description` → "Delete all user profiles and replace them with the imported ones." / "Elimina tutti i profili utente e sostituiscili con quelli importati."
   - `import.json.replace.confirm.title` → "Replace all user profiles?" / "Sostituire tutti i profili utente?"
   - `import.json.replace.confirm.message` → "%d existing profiles will be deleted. This action cannot be undone." / "Verranno eliminati %d profili esistenti. L'azione non può essere annullata."
   - `import.json.replace.confirm.button` → "Delete and import" / "Elimina e importa"
   - `profile.import.suffix` → "%@ (imported)" / "%@ (importato)"
   - `profile.import.suffix_numbered` → "%1$@ (imported %2$d)" / "%1$@ (importato %2$d)"
   - `error.import.json.invalid` → "Invalid JSON file." / "File JSON non valido."
   - `error.import.json.unsupported_version` → "Unsupported version: %1$d (max supported: %2$d)." / "Versione non supportata: %1$d (massima supportata: %2$d)."
   - (`error.import.read_failed` esiste già, riuso.)

### 6. Verifica
6. [ ] `xcodegen generate` (nuovi file in `Helpers/` e `Views/Settings/`).
7. [ ] `xcodebuild … build` → BUILD SUCCEEDED.
8. [ ] Verifica manuale (non automatizzabile da CLI):
   - Export di un set di profili → file `hostflow-export-*.json`.
   - "Importa da JSON…" in modalità Merge → i profili appaiono con eventuale suffisso "(importato)".
   - "Importa da JSON…" in modalità Replace → alert di conferma con conteggio corretto → conferma → i profili utente vengono sostituiti.
   - File JSON manualmente corrotto / con `"version": 99` → alert di errore appropriato.

## Out of scope
- Migrations multi-versione (oggi esiste solo v1).
- Preview record-per-record o per-profilo (solo conteggi totali).
- Voce nel menu File globale.
- Merge "intelligente" (match per nome → unione record): il merge attuale è additivo.
- Trigger di `writeHosts` post-import (i profili importati sono inattivi).
- Persistenza/recupero UUID originali (omessi dallo schema export per scelta).
- Round-trip test in XCTest.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-15

**Resolution:** Added `ImportJSONService` + `ImportMode` + `ProfileStore.applyImport` with collision-safe naming, plus an `ImportJSONSheet` (totals + segmented Merge/Replace + destructive replace confirmation). The existing "Import…" button in Advanced now exposes a Menu with "From hosts file…" and "From JSON…". No post-import writeHosts (profiles arrive inactive). Build verified after `xcodegen` regeneration.
