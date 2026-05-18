# Plan: Sortable host records

**Date:** 2026-05-18
**Type:** feature

## Original prompt
> voglio che i record all'interno del profilo siano ordinabili per "hostname" e "IP".

## Summary
Abilita il sort per le colonne `Hostname` e `IP` nella tabella dei record all'interno di un profilo. Il sort è di sessione (non persistito) e si attiva tramite click sull'header della colonna, alternando asc → desc. Nessun drag-and-drop, nessun riordino manuale, nessuna modifica al modello dati né alla scrittura di `/etc/hosts`.

## Steps

1. [ ] **View**: in `ProfileDetailView` introdurre `@State private var sortOrder: [KeyPathComparator<HostRecord>] = []` e passarlo a `Table(of:selection:sortOrder:)` — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
2. [ ] **View**: marcare la `TableColumn("profile.detail.column.hostname")` con `sortUsing: KeyPathComparator(\HostRecord.hostname)` — abilita il click sull'header
3. [ ] **View**: marcare la `TableColumn("profile.detail.column.ip")` con `sortUsing: KeyPathComparator(\HostRecord.ip)` — abilita il click sull'header
4. [ ] **View**: aggiornare `filteredRecords` per applicare `sortOrder` se non vuoto (`records.sorted(using: sortOrder)`); se vuoto, mantenere l'ordine attuale
5. [ ] **Test manuale**: build + run, verificare: (a) click su header Hostname alterna asc/desc, (b) click su header IP alterna asc/desc, (c) il sort interagisce correttamente con la search/filter, (d) il sort è disponibile anche sui profili read-only (sola lettura)

## Out of scope
- Drag-and-drop / riordino manuale dei record
- Persistenza del sort di colonna (solo di sessione)
- Sort per colonna Enabled
- Modifiche al modello `HostRecord` o alla scrittura di `/etc/hosts`

## Open questions
- Nessuna
