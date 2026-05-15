# Plan: Export tutti i profili come JSON

**Date:** 2026-05-15
**Type:** feature
**Ref:** [.task/features/35-export-json.md](.task/features/35-export-json.md)

## Original prompt
> @.task/features/35-export-json.md — Esportare tutti i profili e relativi record in un file JSON strutturato, importabile da altre installazioni di Host Flow. Schema versionato `{"version": 1, "profiles": [...]}`.

## Summary
Aggiungere un'azione "Esporta tutto…" nella sezione Advanced di `SettingsView` che produca un JSON versionato (pretty + sortedKeys) contenente tutti i profili utente e i loro record. Il payload viene scritto via `NSSavePanel` (content type `.json`) con default filename `hostflow-export-<YYYY-MM-DD>.json`. Successo notificato da un HUD transiente coerente con il detail; errori via `.alert` nativo.

## Decisioni prese durante il grilling
- **Profilo Default:** **escluso** dall'export (filtrato con `!isReadOnly`).
- **Schema (vs. spec):** lo schema è più stretto di quanto indicato nel task file. I campi `id`, `isActive`, `isReadOnly` sono **omessi** per scelta esplicita:
  - `id` → omesso (UUID rigenerati a un eventuale import).
  - `isActive` → omesso (i profili importati arrivano disattivati per non sovrascrivere `/etc/hosts`).
  - `isReadOnly` → omesso (i profili importati sono sempre editabili).
- **UI:** bottone "Esporta tutto…" in `SettingsView` → sezione Advanced (sopra "Pulisci /etc/hosts").
- **Feedback successo:** HUD transiente in stile capsule material, riuso dello stesso pattern di `ProfileDetailView`.
- **Test round-trip:** fuori scope (no target XCTest oggi).

## Schema JSON

```json
{
  "version" : 1,
  "profiles" : [
    {
      "name" : "Dev",
      "order" : 1,
      "records" : [
        { "ip" : "127.0.0.1", "hostname" : "api.local", "isEnabled" : true },
        { "ip" : "127.0.0.1", "hostname" : "old.local", "isEnabled" : false }
      ]
    }
  ]
}
```

Encoding: `JSONEncoder` con `outputFormatting = [.prettyPrinted, .sortedKeys]`.

## Steps

### 1. DTO Codable
1. [ ] Nuovo file [`HostFlow/Helpers/ExportPayload.swift`](HostFlow/Helpers/ExportPayload.swift) contenente:
   - `struct RecordExport: Codable { let ip: String; let hostname: String; let isEnabled: Bool }`
   - `struct ProfileExport: Codable { let name: String; let order: Int; let records: [RecordExport] }`
   - `struct ExportPayload: Codable { let version: Int; let profiles: [ProfileExport] }`
   - `static let currentVersion = 1` su `ExportPayload`.

### 2. ExportService
2. [ ] Nuovo file [`HostFlow/Helpers/ExportService.swift`](HostFlow/Helpers/ExportService.swift):
   - `enum ExportService` con `static func exportAll(profiles: [Profile]) throws -> Data`
   - Filtra `profiles.filter { !$0.isReadOnly }`, mappa su `ProfileExport` (e records ordinati come da `profile.records`), avvolge in `ExportPayload(version: ExportPayload.currentVersion, profiles: ...)`.
   - Encoder: `.prettyPrinted, .sortedKeys`.

### 3. UI in SettingsView
3. [ ] [`HostFlow/Views/Settings/SettingsView.swift`](HostFlow/Views/Settings/SettingsView.swift):
   - Aggiungere stato `@State private var hudMessage: LocalizedStringKey?`, `@State private var exportError: String?`.
   - Nella `Section("settings.section.advanced")`, sopra la riga "Pulisci /etc/hosts", aggiungere riga con:
     ```swift
     VStack(alignment: .leading, spacing: 4) {
         Text("settings.advanced.export.title")
         Text("settings.advanced.export.description")
             .font(.caption)
             .foregroundStyle(.secondary)
     }
     Spacer()
     Button("settings.advanced.export.button") { exportAll() }
         .buttonStyle(.borderedProminent)
     ```
   - `private func exportAll()`:
     - Recupera profili via `try? modelContext.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.order)]))`.
     - Genera `Data` tramite `ExportService.exportAll(profiles:)`.
     - `NSSavePanel` con `allowedContentTypes = [.json]`, `title = "settings.advanced.export.panel.title"`, `nameFieldStringValue = defaultFilename`.
     - `panel.begin { ... }`: on `.OK` → `try data.write(to: url)`, on success → `showHUD("settings.advanced.export.done")`, on error → `exportError = error.localizedDescription`.
   - `private var defaultExportFilename`: `"hostflow-export-\(ISO date YYYY-MM-DD).json"`. Uso `Date.ISO8601FormatStyle(dateSeparator: .dash).year().month().day()` oppure `DateFormatter` configurato con `"yyyy-MM-dd"` + `Locale(identifier: "en_US_POSIX")`.

### 4. HUD + alert in SettingsView
4. [ ] Stessa struttura usata in `ProfileDetailView`: `.overlay(alignment: .top)` con `Label(hudMessage, systemImage: "checkmark.circle.fill")` in capsule material, 1.5s di auto-dismiss tramite `Task { sleep(1500ms); hudMessage = nil }`.
5. [ ] `.alert("settings.advanced.export.error.title", isPresented: ..., presenting: exportError)` come fatto altrove.

### 5. Stringhe localizzate
6. [ ] [`HostFlow/Resources/Localizable.xcstrings`](HostFlow/Resources/Localizable.xcstrings) — nuove chiavi (EN / IT):
   - `settings.advanced.export.title` → "Export all profiles" / "Esporta tutti i profili"
   - `settings.advanced.export.description` → "Save a JSON archive with every user profile and its records." / "Salva un archivio JSON con tutti i profili utente e i relativi record."
   - `settings.advanced.export.button` → "Export…" / "Esporta…"
   - `settings.advanced.export.panel.title` → "Export profiles" / "Esporta profili"
   - `settings.advanced.export.done` → "Exported" / "Esportato"
   - `settings.advanced.export.error.title` → "Failed to export" / "Esportazione non riuscita"

### 6. Verifica
7. [ ] `xcodebuild -project HostFlow.xcodeproj -scheme HostFlow -configuration Debug -destination 'platform=macOS' build` → BUILD SUCCEEDED.
8. [ ] Verifica manuale (non eseguibile da CLI): click "Esporta…", scegli destinazione, apri il file `.json` prodotto e controlla che il payload contenga solo profili utente, chiavi ordinate alfabeticamente, indentazione 2 spazi.

## Out of scope
- Import / restore da JSON (sarà una task separata).
- Test round-trip in XCTest (no target di test nel progetto).
- Voce nel menu File globale (CommandGroup).
- Inclusione del profilo Default nell'export.
- Persistenza di UUID, `isActive`, `isReadOnly` nel payload.
- Compressione / cifratura del file esportato.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-15

**Resolution:** Added Codable DTOs and `ExportService` plus an Advanced-section row in `SettingsView` with `NSSavePanel`/JSON output, HUD success feedback and native error alert. Schema tightened (no `id`/`isActive`/`isReadOnly`); Default excluded. Build verified after `xcodegen` regeneration.
