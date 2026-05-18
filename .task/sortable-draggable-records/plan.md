# Plan: Sortable & draggable host records

**Date:** 2026-05-18
**Type:** feature

## Original prompt
> voglio che i record all'interno del profilo siano ordinabili per "hostname" e sia possibile anche trascinare un record e spostarlo più in alto o in basso nella lista.

## Summary
Aggiunge il riordino manuale (drag-and-drop) dei record host all'interno di un profilo e il sort per colonna `Hostname` (asc → desc → manuale). L'ordine manuale viene persistito tramite un nuovo campo `order: Int` su `HostRecord` e applicato anche alla scrittura di `/etc/hosts`. Il drag esistente verso i profili in sidebar resta attivo: drop su altra row = riordino interno, drop su sidebar = move cross-profilo.

## Steps

1. [ ] **Model**: aggiungere `var order: Int = 0` a `HostRecord` (default valore per consentire migrazione SwiftData automatica) — `HostFlow/Models/HostRecord.swift`
2. [ ] **Model**: aggiornare l'init di `HostRecord` con parametro `order: Int = 0`
3. [ ] **Store**: aggiungere helper `ProfileStore.normalizeOrder(for profile:, context:)` che assegna order sequenziale (0, 1, 2…) sui record basandosi sull'ordine corrente di `profile.records`, da chiamare quando si rileva che tutti gli order sono 0 o ci sono duplicati — `HostFlow/Stores/ProfileStore.swift`
4. [ ] **Store**: aggiungere `ProfileStore.reorderRecords(in profile:, draggedIDs:, toIndex:, context:)` che ricalcola gli `order` dopo un drop, salva e schedula la scrittura su `/etc/hosts`
5. [ ] **Store**: nel metodo che crea nuovi record (es. `addRecord` o equivalente, e in `AddRecordSheet` / `moveRecords`) impostare `order = (profile.records.map(\.order).max() ?? -1) + 1` così i nuovi record vanno in fondo
6. [ ] **Hosts writer**: ordinare `profile.records` per `order` in `HostsFileManager.formatProfile` (riga 48) e in `HostsFileManager.buildBlock` (riga 130) — `HostFlow/Helpers/HostsFileManager.swift`
7. [ ] **View**: in `ProfileDetailView` introdurre `@State private var sortOrder: [KeyPathComparator<HostRecord>] = []` e passarlo a `Table(of:selection:sortOrder:)`
8. [ ] **View**: marcare la `TableColumn("profile.detail.column.hostname")` con `sortUsing: KeyPathComparator(\HostRecord.hostname)` — questo abilita il click sull'header
9. [ ] **View**: aggiornare `filteredRecords` per applicare prima il sort manuale (per `order`) e poi sovrascrivere con `sortOrder` se non vuoto; tornare `sortOrder = []` per ripristinare il manuale
10. [ ] **View**: su ogni `TableRow` aggiungere `dropDestination(for: HostRecordTransfer.self)` (solo se `!profile.isReadOnly && searchText.isEmpty && sortOrder.isEmpty` — quando il sort è attivo il drop reset + reorder). Nel callback: se i dragged ID appartengono allo stesso profilo → `store.reorderRecords(...)` e azzerare `sortOrder`; se appartengono ad altro profilo → comportamento attuale (delegare a logica esistente di move cross-profilo, già gestita dalla sidebar; qui ignoriamo per evitare duplicazione)
11. [ ] **View**: on appear chiamare `store.normalizeOrder(for: profile, context: context)` per migrare record esistenti con order=0
12. [ ] **Test manuale**: build + run, verificare: (a) click su Hostname header alterna asc/desc/manual, (b) drag di una row su un'altra row la riposiziona e resetta il sort, (c) drag verso sidebar continua a spostare cross-profilo, (d) durante search il drag-to-reorder è disabilitato, (e) profilo read-only non permette nessuna delle due, (f) `/etc/hosts` riflette il nuovo ordine

## Out of scope
- Sort per colonne IP o Enabled
- Persistenza del sort di colonna (solo di sessione)
- Drag-and-drop multi-selezione con riordino (se più item sono selezionati e trascinati, riordino single-item come fallback)
- Modifiche al drop target sulla sidebar (resta com'è)

## Open questions
- Nessuna
