# Plan: Order automatico + persistenza ordering

**Date:** 2026-05-07
**Type:** chore

## Summary

Garantire ordering deterministico dei `Profile`: l'`addProfile` corrente usa `count` come nuovo order, generando duplicati dopo delete. Sostituire con `max(order) + 1`. Aggiungere `reorder(_:context:)` che riassegna `order = index` su una lista già ordinata (per drag-reorder futuro). Verificare che le query esistenti usino già `sort: \Profile.order`.

## Steps

1. [x] `ProfileStore.addProfile` — sostituire `count` con `max(order) + 1` (0 se vuoto) — `HostFlow/Stores/ProfileStore.swift`
2. [x] `ProfileStore.reorder(_ profiles: [Profile], context: ModelContext)` — riassegna `order = index` per ogni profilo nella lista, salva contesto
3. [x] Verifica `@Query(sort: \Profile.order)` già presente in `SidebarView` e `MenuBarView` (no-op se già OK)
4. [x] Build verifica

## Out of scope

- UI drag-reorder (`.onMove`) → task `12-sidebar-reorder`
- Recompact order su delete (gap permessi, non necessario reindicizzare)
- Ordering dei `HostRecord` dentro un profilo (non richiesto da task)

## Open questions

- Nessuna
