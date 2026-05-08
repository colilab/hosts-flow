# Task: Record — Ricerca/filtro

## Obiettivo

Search bar nel pane destro che filtra i record visibili per IP o hostname (case-insensitive, contains), con empty state dedicato quando la query non produce match.

## Stato attuale (pre-task)

Durante l'iterazione UI (cambio a `HSplitView`) il `.searchable` nativo SwiftUI è stato sostituito con un **TextField manuale** dentro `ProfileDetailView` (`searchBar`). Già presenti:
- `@State searchText`
- `searchBar` (icona lupa + TextField + bottone clear `xmark.circle.fill`)
- `filteredRecords` computed con match case-insensitive su `ip` + `hostname`

## Cosa resta da fare

- [ ] Empty state quando `!searchText.isEmpty && filteredRecords.isEmpty`:
  - `ContentUnavailableView` con messaggio "Nessun record trovato per '\(searchText)'"
  - icona `magnifyingglass`
  - mostrato al posto della Table dei record
- [ ] Test manuale: profilo con N record → query "local" → solo matching visibili → query inesistente → empty state

## Out of scope

- `.searchable` nativo — abbandonato per problemi di overlap con `HSplitView` (vedi changelog)
- Highlight dei termini matchati — non richiesto, complessità Table custom

## Note tecniche

- L'empty state va dentro `recordsList`'s parent — sostituisce la Table quando il filtro è attivo e vuoto
- Performance OK fino a ~10k record senza ottimizzazioni

---

**Completed:** 2026-05-07

**Resolution:** Aggiunto branch `ContentUnavailableView.search(text:)` nel body di `ProfileDetailView` per il caso `!searchText.isEmpty && filteredRecords.isEmpty`. Tutto il resto (search bar, filter, clear button) era già in place dal refactor HSplitView.
