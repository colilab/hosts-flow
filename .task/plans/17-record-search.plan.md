# Plan: Record — Ricerca/filtro

**Date:** 2026-05-07
**Type:** feature

## Summary

L'unica cosa che manca è l'empty state quando la ricerca non produce match. Aggiungere un terzo branch nel body di `ProfileDetailView` con `ContentUnavailableView.search` (variante nativa SwiftUI per ricerca vuota) che mostra `"Nessun risultato"` con la query.

## Steps

1. [x] In `ProfileDetailView.body`: estendere il `if/else` per gestire 3 casi: (a) profilo senza record, (b) ricerca attiva senza match, (c) records visibili
2. [x] Caso (b): `ContentUnavailableView.search(text: searchText)` — variante nativa, mostra "Nessun risultato per '<query>'"
3. [x] Build verifica

## Out of scope

- `.searchable` nativo — già abbandonato per problemi con `HSplitView`
- Highlight termini matchati nella Table

## Open questions

- Nessuna
