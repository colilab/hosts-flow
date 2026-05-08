# Plan: Profile — Flag readonly (system profile)

**Date:** 2026-05-07
**Type:** chore

## Summary

Aggiungere un flag `isReadOnly: Bool` al model `Profile` per marcare i profili di sistema (es. il Default seed da `/etc/hosts`) come non modificabili. Esporre un computed `isEditable`, un helper `ProfileStore.canEdit`, e mostrare un'icona lock + tooltip nella sidebar quando readonly. I guard concreti sulle azioni (rinomina, edit record, delete, ecc.) sono delegati ai task successivi che già li menzionano nelle checklist.

## Steps

1. [x] `Profile.swift` — aggiungere `var isReadOnly: Bool` con default `false`, parametro di init opzionale, computed `var isEditable: Bool { !isReadOnly }`
2. [x] `ProfileStore.swift` — aggiungere helper `func canEdit(_ profile: Profile) -> Bool`
3. [x] `SidebarView.swift` `ProfileRowView` — aggiungere `Image(systemName: "lock.fill")` accanto al nome se `profile.isReadOnly` (caption font, color secondary) + `.help("Profilo di sistema — duplica per modificare")` sulla row
4. [x] Verificare che la lightweight migration SwiftData gestisca il nuovo campo (default value, no schema breaking) — build + run app con store esistente, no crash

## Out of scope

- Logica di seed del profilo Default con `isReadOnly = true` → task `06-data-seed`
- Guard concreti su rinomina / delete / edit record → task `09-sidebar-rename-inline`, `10-sidebar-delete`, `11-sidebar-context-menu`, `13-record-add`, `14-record-edit-inline`, `15-record-toggle`, `16-record-delete`
- Funzione duplica profilo → task `11-sidebar-context-menu`
- Persistence schema migration manuale — SwiftData fa lightweight migration automatica per add property con default

## Open questions

- Nessuna
