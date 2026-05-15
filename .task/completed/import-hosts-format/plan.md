# Plan: Import file /etc/hosts come nuovo profilo

**Date:** 2026-05-15
**Type:** feature
**Ref:** [.task/features/36-import-hosts-format.md](.task/features/36-import-hosts-format.md)

## Original prompt
> @.task/features/36-import-hosts-format.md — Importare un file in formato `/etc/hosts` come nuovo profilo (commentati = disabled). File picker, parser tollerante, anteprima record con nome editabile, profilo creato `isActive = false`.

## Summary
Aggiungere in `SettingsView` → Advanced un bottone "Importa…" che apra un `NSOpenPanel`, parsi il file con il `HostsFileParser` esistente (gestisce già righe commentate, marker Host Flow, hostname multipli per riga), e presenti un'anteprima in uno sheet con **nome profilo editabile** (precompilato dal filename) e tabella read-only dei record. Conferma → crea un nuovo profilo `isActive = false` con i record parsati. Errore "Nessun record valido" o lettura fallita → `.alert` nativo prima dello sheet.

## Decisioni prese durante il grilling
- **UI:** bottone "Importa…" in `SettingsView` → Advanced, sopra "Esporta…".
- **Collisione nome:** sheet con `TextField` editabile (validazione duplicato live, riuso pattern di `AddProfileSheet`).
- **File types accettati:** `[.plainText, .data]` per accogliere file senza estensione (es. `/etc/hosts`).
- **Empty/error:** `.alert` nativo immediato, sheet non aperto.
- **Post-import:** nessuna selezione automatica (l'utente è in Settings, scene separata).
- **Parser:** **già esistente** in [`HostsFileParser.parse(_:)`](HostFlow/Helpers/HostsFileParser.swift) — gestisce skip vuoti/commenti puri, record commentati (`# ip hostname`), regex implicita via tokenizer + `HostValidator`, hostname multipli per riga (genera N record). I marker `# --- Host Flow Start/End ---` vengono naturalmente scartati (primo token `---` non è IP).

## Steps

### 1. Import service
1. [ ] Nuovo file [`HostFlow/Helpers/ImportService.swift`](HostFlow/Helpers/ImportService.swift):
   ```swift
   enum ImportError: LocalizedError {
       case readFailed(String)
       case noValidRecords
       var errorDescription: String? { ... }
   }

   struct ImportResult {
       let suggestedName: String     // filename senza estensione
       let records: [ParsedHostRecord]
   }

   enum ImportService {
       static func parseFile(at url: URL) throws -> ImportResult {
           let content: String
           do { content = try String(contentsOf: url, encoding: .utf8) }
           catch { throw ImportError.readFailed(error.localizedDescription) }

           let records = HostsFileParser.parse(content)
           guard !records.isEmpty else { throw ImportError.noValidRecords }

           let name = url.deletingPathExtension().lastPathComponent
           return ImportResult(suggestedName: name, records: records)
       }
   }
   ```
   Localizza `ImportError`:
   - `error.import.read_failed` → "Could not read file: %@" / "Impossibile leggere il file: %@"
   - `error.import.no_valid_records` → "No valid records found in the selected file." / "Nessun record valido trovato nel file selezionato."

### 2. Preview sheet
2. [ ] Nuovo file [`HostFlow/Views/Settings/ImportProfileSheet.swift`](HostFlow/Views/Settings/ImportProfileSheet.swift):
   - `struct ImportProfileSheet: View` con properties:
     - `let suggestedName: String`
     - `let records: [ParsedHostRecord]`
     - `let existingNames: [String]`
     - `let onImport: (String) -> Void`  (riceve il nome finale)
     - `@State name: String = suggestedName`, `@FocusState`, `@Environment(\.dismiss)`
   - Layout: `VStack` (24pt padding, width 480):
     - `Text("import.sheet.title").font(.headline)`
     - `TextField("profile.add.field.name.placeholder", text: $name)` con error label `profile.add.error.duplicate` se collide (case-insensitive)
     - `Text("import.records.count \(records.count)")` (chiave plurale localizzata)
     - `Table(records)` con 3 colonne: `import.column.ip`, `import.column.hostname`, `import.column.enabled` (icona `checkmark.circle` / `xmark.circle` colorata). Frame fisso ~200pt altezza.
     - HStack: `Spacer`, `Button("common.button.cancel", role: .cancel)`, `Button("import.button.import").disabled(!canImport)`.
   - `canImport`: nome trimmed non vuoto e non duplicato.
   - `ParsedHostRecord` non è `Identifiable`: usare wrapper con `UUID()` o `Table` con `id: \.<KeyPath>`. Soluzione semplice: locale `struct PreviewRow: Identifiable { let id = UUID(); let record: ParsedHostRecord }` mappato all'init.

### 3. Wire in SettingsView
3. [ ] [`HostFlow/Views/Settings/SettingsView.swift`](HostFlow/Views/Settings/SettingsView.swift):
   - Aggiungere stato: `@State private var importResult: ImportResult?`, `@State private var importError: String?`, `@State private var existingProfileNames: [String] = []`.
   - In `Section("settings.section.advanced")` aggiungere riga "Importa…" **sopra** "Esporta…":
     ```swift
     HStack {
         VStack(alignment: .leading, spacing: 4) {
             Text("settings.advanced.import.title")
             Text("settings.advanced.import.description")
                 .font(.caption).foregroundStyle(.secondary)
         }
         Spacer()
         Button("settings.advanced.import.button") { startImport() }
             .buttonStyle(.bordered)
     }
     ```
   - `private func startImport()`:
     - `NSOpenPanel()` con `allowedContentTypes = [.plainText, .data]`, `allowsMultipleSelection = false`, `canChooseDirectories = false`, `title = "settings.advanced.import.panel.title"`.
     - `panel.begin { response in ... }`: on `.OK`, prova `ImportService.parseFile(at: url)`. On success → fetch profili attuali in `existingProfileNames`, set `importResult`. On error → `importError = error.localizedDescription`.
   - `.sheet(item: $importResult)` (richiede `ImportResult: Identifiable` — aggiungere `let id = UUID()` come property, o wrappare in `IdentifiableBox`).
   - Action `onImport: { name in createProfile(name: name, records: result.records); importResult = nil }`.
   - `private func createProfile(name: String, records: [ParsedHostRecord])`:
     ```swift
     let profile = store.addProfile(name: name, context: modelContext)
     for r in records {
         let record = HostRecord(ip: r.ip, hostname: r.hostname, profile: profile)
         record.isEnabled = r.isEnabled
         modelContext.insert(record)
     }
     try? modelContext.save()
     showHUD("settings.advanced.import.done")
     ```
     (riusa l'`hudMessage`/`showHUD` esistente). Niente `scheduleWrite` perché il profilo nasce `isActive = false`.
   - `.alert("settings.advanced.import.error.title", isPresented: $importError)` (pattern già usato per export).

### 4. Stringhe localizzate
4. [ ] [`HostFlow/Resources/Localizable.xcstrings`](HostFlow/Resources/Localizable.xcstrings) — nuove chiavi (EN / IT):
   - `settings.advanced.import.title` → "Import profile from file" / "Importa profilo da file"
   - `settings.advanced.import.description` → "Create a new profile by importing a hosts-format file." / "Crea un nuovo profilo importando un file in formato hosts."
   - `settings.advanced.import.button` → "Import…" / "Importa…"
   - `settings.advanced.import.panel.title` → "Import hosts file" / "Importa file hosts"
   - `settings.advanced.import.done` → "Imported" / "Importato"
   - `settings.advanced.import.error.title` → "Failed to import" / "Importazione non riuscita"
   - `import.sheet.title` → "Import profile" / "Importa profilo"
   - `import.records.count` (plural) → "%d records" (one: "%d record") / "%d record" (one: "%d record")
   - `import.column.ip` → "IP" / "IP"
   - `import.column.hostname` → "Hostname" / "Hostname"
   - `import.column.enabled` → "Enabled" / "Abilitato"
   - `import.button.import` → "Import" / "Importa"
   - `error.import.read_failed` → "Could not read file: %@" / "Impossibile leggere il file: %@"
   - `error.import.no_valid_records` → "No valid records found in the selected file." / "Nessun record valido trovato nel file selezionato."

### 5. Verifica
5. [ ] `xcodegen generate` (nuovi file in `Helpers/` e `Views/Settings/`).
6. [ ] `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → BUILD SUCCEEDED.
7. [ ] Verifica manuale (non automatizzabile da CLI): import di `/etc/hosts` → sheet anteprima → conferma → profilo `isActive=false` con i record visibili in sidebar.

## Out of scope
- Menu globale "File → Importa…" (rimaniamo coerenti con la scelta UI in Settings).
- Import multi-file.
- Import del JSON prodotto da `ExportService` (sarà una task separata).
- Merge / dedup contro profili esistenti.
- Toggling `isActive` automatico dopo import.
- Selezione automatica del profilo importato nella sidebar.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-15

**Resolution:** Added `ImportService` + `ImportProfileSheet` (editable name, records preview Table) wired from `SettingsView` Advanced section. Reused existing `HostsFileParser.parse(_:)`. Errors surface via native alert; success creates an inactive profile and triggers the HUD. Build verified after `xcodegen` regeneration.
