# Task: Sidebar — Rinomina profilo inline

## Obiettivo

Permettere rinomina inline di un profilo via double-click sulla row sidebar: il `Text` diventa `TextField`, conferma con Invio, annulla con Esc.

## Requisiti

- Double-click → editing mode
- Invio salva, Esc annulla
- Click fuori dal field salva (commit on blur)
- Validazione duplicato → revert al nome precedente + warning visivo

## Checklist

- [ ] **Guard readonly**: se `profile.isReadOnly`, double-click NON attiva editing (no-op)
- [ ] State `@State var editingProfileID: UUID?` in `SidebarView`
- [ ] In `ProfileRow`: condizionale `Text` vs `TextField` basato su `editingProfileID == profile.id`
- [ ] `.onTapGesture(count: 2)` per attivare editing
- [ ] `.onSubmit` salva via `profile.name = ...` + reset `editingProfileID`
- [ ] `onExitCommand` (Esc) → revert
- [ ] FocusState per autofocus al TextField
- [ ] Validazione duplicato su submit, mostra errore con shake o alert

## Note tecniche

- `@FocusState` per gestione focus + autofocus
- Bordo TextField: `.textFieldStyle(.plain)` per blend con la row

---

**Completed:** 2026-05-07

**Resolution:** Rinomina inline via double-click su Text → TextField con `@FocusState` autofocus. Submit, Esc, blur gestiti. Duplicate case-insensitive (escludendo self) → flash rosso 1s + revert. Profilo readonly: double-click no-op.
