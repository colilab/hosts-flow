# Task: Sidebar — Elimina profilo

## Obiettivo

Eliminare un profilo dalla sidebar via context menu o tasto Delete, con alert di conferma. Cascata su `HostRecord` collegati.

## Requisiti

- Context menu con voce "Elimina"
- Tasto Delete sulla row selezionata triggera la stessa azione
- Alert conferma "Eliminare profilo X? L'azione non può essere annullata"
- Cascade delete dei record (già configurato in `Profile.records` con `.cascade`)
- Trigger riscrittura `/etc/hosts` se profilo era attivo

## Checklist

- [ ] **Guard readonly**: se `profile.isReadOnly`, voce "Elimina" disabilitata + tasto Delete no-op
- [ ] `.contextMenu` su ProfileRow con voce "Elimina" (red)
- [ ] Keyboard shortcut Delete su selected row
- [ ] Alert conferma con `Bool` state
- [ ] `ProfileStore.deleteProfile(_:context:)` rimuove + chiama `writeHosts` se era active
- [ ] Auto-select profilo successivo (o nessuno se vuoto)
- [ ] Test cascade: profilo con N record eliminato → record rimossi da SwiftData

## Note tecniche

- `.onDeleteCommand` per tasto Delete a livello List
- Alert: `.confirmationDialog` per stile più macOS-like su distruttive
