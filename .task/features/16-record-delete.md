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

- [ ] **Guard readonly**: se profilo `isReadOnly`, voce "Elimina" disabilitata + Delete key no-op
- [ ] `.contextMenu(forSelectionType:)` con voce "Elimina"
- [ ] `.onDeleteCommand` o `keyboardShortcut(.delete)`
- [ ] Selection state `Set<UUID>` per multi-select
- [ ] `ProfileStore.deleteRecords(_:context:)` accetta lista
- [ ] Test: select 3 record + Delete → tutti rimossi

## Note tecniche

- `Table` su macOS supporta `selection: Binding<Set<UUID>>`
- `forSelectionType: HostRecord.ID.self` per typed selection
