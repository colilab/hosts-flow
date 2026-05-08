# Plan: Sidebar — Context menu completo

**Date:** 2026-05-07
**Type:** feature

## Summary

Estendere il `.contextMenu` esistente sulla row sidebar con: Rinomina (riusa `editingProfileID`), Duplica (nuovo helper `ProfileStore.duplicate`), Elimina (già presente), divider, Attiva/Disattiva (toggle dinamico). Aggiungere `duplicate(profile:context:)` allo store con naming "(copia)", "(copia 2)" ecc., copia profonda dei record con nuovi UUID, copia editabile (`isReadOnly = false`).

## Steps

1. [x] In `ProfileStore.swift`: aggiungere `duplicate(_ profile: Profile, context: ModelContext) -> Profile`:
   - calcola nome unico via helper `uniqueDuplicateName(base:among:)` (case-insensitive)
   - nuovo Profile `isActive = false`, `isReadOnly = false`, order = `(max + 1)`
   - per ogni record sorgente: nuovo `HostRecord` con stesso `ip`/`hostname`/`isEnabled` ma nuovo UUID, attached al duplicato
   - context.save + return new Profile
2. [x] Helper privato `private func uniqueDuplicateName(base: String, among existing: [String]) -> String` — prova `<base> (copia)`, poi `<base> (copia 2)`, ...
3. [x] In `SidebarView` `.contextMenu` su row, ricostruire menu con:
   - Button "Rinomina" `.disabled(profile.isReadOnly)` → setta `editingProfileID = profile.id`
   - Button "Duplica" → chiama `let new = store.duplicate(profile:context:); selectedProfile = new`
   - Button "Elimina" `role: .destructive` `.disabled(profile.isReadOnly)` → `profileToDelete = profile`
   - `Divider()`
   - Button con label dinamica `"Attiva"` / `"Disattiva"` `.disabled(profile.isReadOnly)` → `profile.isActive.toggle(); store.writeHosts(context:)`
4. [x] Build verifica

## Out of scope

- Toggle "attiva/disattiva" disponibile su readonly — per coerenza con la decisione "tutto disabilitato sul Default" applichiamo anche qui il guard readonly. (La checklist task originale aveva intent diverso, sovrascritta dalla scelta utente.)
- Animazioni di duplicate / feedback — il duplicato viene auto-selezionato, sufficiente come feedback
- Drag-reorder dei profili → task `12-sidebar-reorder`

## Open questions

- Nessuna
