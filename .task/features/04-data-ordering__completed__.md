# Task: Order automatico + persistenza ordering

## Obiettivo

Garantire che ogni `Profile` abbia un `order` coerente: assegnato automaticamente alla creazione (max + 1) e ricalcolato dopo drag-reorder.

## Requisiti

- Order deterministico, no duplicati
- Compatibile con drag-reorder (task 03-sidebar-reorder)
- Recompact su delete: nessun gap obbligatorio (usare order come hint, non come slot fisso)

## Checklist

- [ ] In `ProfileStore.addProfile(name:context:)` calcolare `order = (max esistente) + 1`
- [ ] `func reorder(_ profiles: [Profile])` — accetta lista riordinata, riassegna `order = index`
- [ ] `@Query` profili usa `sort: [SortDescriptor(\.order)]`
- [ ] Test: creazione 3 profili → ordini 0,1,2; reorder → indici aggiornati

## Note tecniche

- SwiftData: usare `FetchDescriptor` con `sortBy: [SortDescriptor(\Profile.order)]` per query manuali
- No serializzazione transazionale necessaria (single-user app)

---

**Completed:** 2026-05-07

**Resolution:** `addProfile` ora usa `max(order) + 1` invece di `count` (fix bug duplicati dopo delete). Aggiunto `ProfileStore.reorder(_:context:)` per il futuro drag-reorder. Query sort già OK.
