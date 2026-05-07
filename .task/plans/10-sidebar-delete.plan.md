# Plan: Sidebar — Elimina profilo

**Date:** 2026-05-07
**Type:** feature

## Summary

Aggiungere context menu "Elimina" sulla row sidebar e shortcut tasto Delete sul profilo selezionato, entrambi protetti da `.confirmationDialog`. Il profilo readonly non è eliminabile (voce disabled, Delete no-op). Dopo l'eliminazione: auto-select del profilo successivo (o precedente se era l'ultimo, o nil se era l'unico). Cascade dei record già garantito da `@Relationship(deleteRule: .cascade)` sul model Profile.

## Steps

1. [x] In `SidebarView`: aggiungere `@State profileToDelete: Profile?`
2. [x] Sulla `ProfileRowView` nel List: aggiungere `.contextMenu { Button("Elimina", role: .destructive) { ... }.disabled(profile.isReadOnly) }`
3. [x] Sul `List`: aggiungere `.onDeleteCommand` che setta `profileToDelete = selectedProfile` (se non readonly)
4. [x] In `SidebarView.body`: `.confirmationDialog` con titolo `"Eliminare profilo \(name)?"`, message "L'azione non può essere annullata. Tutti i record associati verranno rimossi.", bottoni "Elimina" (.destructive) + "Annulla" (.cancel)
5. [x] Helper privato `deleteProfile(_:)`:
   - calcola next selection: prossimo profilo per `order`, fallback al precedente se era l'ultimo, nil se unico
   - `store.deleteProfile(profile, context: context)`
   - aggiorna `selectedProfile`
6. [x] Verifica: `ProfileStore.deleteProfile` già chiama `writeHosts` (in scope: nessuna modifica al store)
7. [x] Build verifica

## Out of scope

- Multi-select delete — task non richiede
- Undo (Cmd+Z) — out of scope, SwiftData supporta `Undo` con configurazione esplicita ma fuori roadmap
- Trigger writeHosts solo se profilo era attivo — il `deleteProfile` attuale lo chiama sempre (write idempotente, no-op se profilo non era nel block)

## Open questions

- Nessuna
