# Plan: Record — Edit inline IP + hostname

**Date:** 2026-05-07
**Type:** feature

## Summary

Editing inline delle celle IP e Hostname della Table dei record via double-click. Stato editing single-cell (`editingCell: CellAddress?`), TextField condizionale, autofocus via `@FocusState`, validazione single-field su submit, Esc annulla, blur fa commit (revert silenzioso se invalid). Return su IP avanza al campo Hostname dello stesso record. Tab gestito come "advance" su IP. Border rosso quando validation fallisce. Profilo readonly: double-click no-op.

## Steps

1. [x] In `ProfileDetailView`: definire `private struct CellAddress: Hashable { enum FieldType { case ip, hostname }; let recordID: UUID; let field: FieldType }`
2. [x] State: `@State editingCell: CellAddress?`, `@State draftValue: String`, `@State validationFailed: Bool`, `@FocusState focusedCell: CellAddress?`
3. [x] Helper `@ViewBuilder editableCell(record:field:value:)`:
   - se `editingCell == address`: `TextField` con monospaced, `.focused($focusedCell, equals: address)`, `.submitLabel(field == .ip ? .next : .return)`, `.onSubmit { commitEdit(record:address:advance:true) }`, `.onExitCommand { cancelEdit() }`, `.onKeyPress(.tab) { commitEdit + advance true; .handled }` (per supportare Tab IP→Hostname), `.onChange(of: focusedCell)` per blur → `commitEdit(advance:false)` se non programmatico, overlay border rosso se `validationFailed`
   - altrimenti: `Text(value)` con `.frame(maxWidth: .infinity, alignment: .leading) .contentShape(Rectangle()) .onTapGesture(count: 2) { startEdit(address, value) }` (guard `!profile.isReadOnly`)
4. [x] Helper privati `startEdit(address:value:)`, `commitEdit(record:address:advance:)`, `cancelEdit()`:
   - `startEdit`: setta draft, reset validationFailed, set editingCell + focusedCell
   - `commitEdit`: trim, validate single field via `HostValidator.isValidIP` o `isValidHostname`, su fail set `validationFailed = true` + return; su success scrive `record.ip` o `record.hostname`, save, `writeHosts`, se `advance && field == .ip` muove a hostname dello stesso record (riempie draft con `record.hostname`), altrimenti chiude editing
   - `cancelEdit`: reset all editing state
5. [x] Sostituire `TableColumn("IP")` e `TableColumn("Hostname")` per usare `editableCell(...)`
6. [x] Build verifica

## Out of scope

- Tab dall'Hostname al record successivo (cross-row navigation)
- Animazioni di transizione Text↔TextField
- Edit di campi multipli simultaneo
- Modal `EditRecordSheet` resta in vita per ora (azione bottone pencil); potremo deprecarlo in un task successivo

## Open questions

- Nessuna
