# Task: Record — Aggiungi record

## Obiettivo

Bottone toolbar nel `ProfileDetailView` che apre `AddRecordSheet` per inserire IP + hostname con validazione.

## Requisiti

- Sheet modale con Form
- Campi IP + hostname con TextField monospaced
- Validazione live (vedi 02-data-validation)
- Default `isEnabled = true`
- Append in fondo alla lista record del profilo

## Checklist

- [ ] **Guard readonly**: se profilo selezionato è `isReadOnly`, toolbar "+" disabilitato + tooltip "Profilo di sistema non modificabile"
- [ ] Toolbar item con SF Symbol `plus` in `ProfileDetailView`
- [ ] State `@State var showAddSheet: Bool` toggle
- [ ] `AddRecordSheet` già esistente — collegare al validator
- [ ] Campo "IP" con placeholder `127.0.0.1`
- [ ] Campo "Hostname" con placeholder `example.local`
- [ ] Pulsante "Aggiungi" disabilitato se invalid
- [ ] On submit: append a `profile.records` + dismiss
- [ ] Trigger `writeHosts` se profilo attivo
- [ ] Focus iniziale sul campo IP

## Note tecniche

- `Form { Section { ... } }.formStyle(.grouped)` per look macOS nativo
- Sheet width: 380pt, height adattiva

---

**Completed:** 2026-05-07

**Resolution:** La maggior parte già implementata da scaffolding + readonly + validation. Aggiunti placeholder via `prompt:` ("127.0.0.1", "example.local") e autofocus sul campo IP via `@FocusState`.
