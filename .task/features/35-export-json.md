# Task: Export — Tutti i profili come JSON

## Obiettivo

Esportare tutti i profili e relativi record in un file JSON strutturato, importabile da altre installazioni di Host Flow.

## Requisiti

- Schema JSON versionato: `{"version": 1, "profiles": [...]}`
- Include: profile (id, name, isActive, order) + records (id, ip, hostname, isEnabled)
- File default: `hostflow-export-<YYYY-MM-DD>.json`
- Pretty-printed (`.prettyPrinted` JSONEncoder)

## Checklist

- [ ] `Codable` DTO: `ProfileExport`, `RecordExport`, `ExportPayload`
- [ ] `ExportService.exportAll(profiles:) -> Data`
- [ ] Menu app "File → Esporta tutto..."
- [ ] `NSSavePanel` con default name + content type `.json`
- [ ] Test round-trip: export → re-import → diff = 0

## Note tecniche

- Schema versioning: future migration via `version` field
- DTO separati da `@Model` per evitare leak di SwiftData internals
- `JSONEncoder().outputFormatting = [.prettyPrinted, .sortedKeys]`
