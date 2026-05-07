# Task: Record — Ricerca/filtro

## Obiettivo

Campo di ricerca in toolbar che filtra i record visibili per IP o hostname (case-insensitive, contains).

## Requisiti

- `.searchable` nativo SwiftUI
- Match su IP O hostname
- Highlight dei termini matchati (opzionale ma consigliato)
- Reset filtro su clear

## Checklist

- [ ] `.searchable(text: $searchQuery)` su `ProfileDetailView`
- [ ] Computed `filteredRecords`: se `searchQuery.isEmpty` → all, else filter
- [ ] Match case-insensitive: `record.ip.localizedCaseInsensitiveContains(q) || record.hostname.localizedCaseInsensitiveContains(q)`
- [ ] Empty state: "Nessun record trovato per '\(query)'" se filtro non matcha
- [ ] Test: 10 record → query "local" → solo matching visibili

## Note tecniche

- `.searchable` posiziona automaticamente il search field nella toolbar su macOS
- Performance OK fino a ~10k record senza ottimizzazioni
