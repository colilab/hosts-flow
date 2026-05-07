# Plan: Sidebar — Rinomina profilo inline

**Date:** 2026-05-07
**Type:** feature

## Summary

Rinomina inline di un profilo nella sidebar via double-click: il `Text` diventa `TextField`, conferma con Invio, annulla con Esc, blur fuori dal field salva. Duplicato (case-insensitive, escludendo self) → revert + flash rosso temporaneo. Profilo readonly → double-click no-op.

## Steps

1. [x] In `SidebarView`: aggiungere `@State editingProfileID: UUID?` a livello parent
2. [x] In `SidebarView` `List`: passare a `ProfileRowView` `isEditing`, `existingNames`, `onBeginEdit`, `onEndEdit`
3. [x] In `ProfileRowView`:
   - aggiungere `@State draftName`, `@FocusState isFieldFocused`, `@State showDuplicateWarning`
   - condizionale `Text` ↔ `TextField` su `isEditing`
   - `Text.onTapGesture(count: 2)` → guard `!profile.isReadOnly` → `draftName = profile.name; onBeginEdit()`
   - `TextField.textFieldStyle(.plain)` + `.focused($isFieldFocused)` + `.onSubmit { commit() }` + `.onExitCommand { onEndEdit() }`
   - `.onChange(of: isFieldFocused)` → blur + isEditing ⇒ `commit()`
   - `.onChange(of: isEditing)` → nuovo true ⇒ `isFieldFocused = true; draftName = profile.name`
   - background row con `.background(showDuplicateWarning ? Color.red.opacity(0.2) : .clear)`
4. [x] `commit()` privato:
   - trim → se vuoto o uguale a `profile.name` → `onEndEdit()` (revert silenzioso)
   - check duplicate case-insensitive escludendo `profile.name` → set `showDuplicateWarning = true`, schedule `false` dopo 1s, `onEndEdit()` (revert)
   - altrimenti → `profile.name = trimmed; try? context.save(); onEndEdit()`
5. [x] Build verifica

## Out of scope

- Rinomina via context menu → task `11-sidebar-context-menu`
- Trigger `writeHosts` su rinomina — il nome compare nei profile sub-headers del blocco; richiede write reale (task 19+). Per ora `try? context.save()` basta a persistere il nome
- Animazioni/shake — flash colore è sufficiente

## Open questions

- Nessuna
