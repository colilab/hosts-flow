# Task: Record — Edit inline IP + hostname

## Obiettivo

Permettere edit inline delle celle IP e Hostname nella `Table` di `ProfileDetailView` via double-click.

## Requisiti

- Double-click sulla cella → TextField inline
- Invio salva, Esc annulla
- Validazione su submit (vedi 02-data-validation)
- Tab passa al campo successivo (IP → Hostname)

## Checklist

- [ ] **Guard readonly**: se profilo `isReadOnly`, double-click sulle celle no-op
- [ ] State `editingRecordID: UUID?` + `editingField: Field` (enum: ip/hostname)
- [ ] Custom `TableColumn` con cella condizionale Text/TextField
- [ ] FocusState per autofocus
- [ ] On submit valido: salva via `record.ip = ...`, reset state
- [ ] On Esc: reset state senza salvare
- [ ] Su validation fail: mantieni TextField + visual error (border rosso)
- [ ] Trigger `writeHosts` su salvataggio se profilo attivo

## Note tecniche

- `Table` columns supportano view custom con accesso a `Bindable` row
- Considerare `EditableTableCell<T>` come component riusabile
- `submitLabel(.next)` per Tab IP→Hostname

---

**Completed:** 2026-05-07

**Resolution:** Implementato il rename con doppio click sul record