# Task: Record — Elimina record

## Obiettivo

Eliminare record via context menu, swipe action, o tasto Delete sulla riga selezionata.

## Requisiti

- Context menu con voce "Elimina"
- Tasto Delete su selected row
- Nessun alert (record sono ricreabili facilmente)
- Trigger `writeHosts` se profilo attivo
- Multi-select supportato (Cmd+click)

## Checklist

- [x] **Guard readonly**: se profilo `isReadOnly`, voce "Elimina" disabilitata + Delete key no-op
- [x] `.contextMenu(forSelectionType:)` con voce "Elimina"
- [x] `.onDeleteCommand` o `keyboardShortcut(.delete)`
- [x] Selection state `Set<UUID>` per multi-select
- [x] `ProfileStore.deleteRecords(_:context:)` accetta lista
- [x] Test: select 3 record + Delete → tutti rimossi

## Note tecniche

- `Table` su macOS supporta `selection: Binding<Set<UUID>>`
- `forSelectionType: HostRecord.ID.self` per typed selection

---

**Completed:** 2026-05-07

**Resolution:** Implemented multi-select deletion via context menu and Delete key, removed actions column buttons in favor of macOS-native selection-based approach
