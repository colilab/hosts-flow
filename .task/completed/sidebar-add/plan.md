# Plan: Sidebar — Aggiungi profilo

**Date:** 2026-05-07
**Type:** feature

## Summary

Sostituire l'attuale `.alert` con un `AddProfileSheet` che permette validazione live (non vuoto + non duplicato case-insensitive), errore inline, autofocus sul TextField, e auto-selezione del profilo creato. `ProfileStore.addProfile` ora restituisce il `Profile` creato per consentire al chiamante di selezionarlo subito.

## Steps

1. [x] `ProfileStore.addProfile(name:context:)` — cambiare return type a `Profile` (ritorna il nuovo profilo) — `HostFlow/Stores/ProfileStore.swift`
2. [x] Creare `HostFlow/Views/Sidebar/AddProfileSheet.swift`:
   - State `@State name: String`
   - `@FocusState` per autofocus
   - Computed `validationError: String?` su trim/empty/duplicate (riceve `existingNames: [String]` come parametro)
   - Bottone "Crea" `.disabled(validationError != nil)`, `Annulla`
   - Errore inline rosso sotto il TextField (caption font)
   - Submit via Invio (`.onSubmit`)
3. [x] In `SidebarView.swift`:
   - Rimuovere `.alert` esistente + state `newProfileName`
   - Sostituire con `.sheet(isPresented: $isAddingProfile)` che presenta `AddProfileSheet`
   - Su create: `let new = store.addProfile(name:context:); selectedProfile = new`
4. [x] `xcodegen generate` per nuovo file
5. [x] Build verifica

## Out of scope

- Rinomina inline → task `09-sidebar-rename-inline`
- Trim case-insensitive ulteriore su rinomina (validato qui solo su create)
- Localizzazione errori — hardcoded italiano (coerente col resto dell'app)

## Open questions

- Nessuna
