# Task: Sidebar — Drag & drop reorder profili

## Obiettivo

Riordinare i profili nella sidebar via drag & drop, persistendo il nuovo ordine in `Profile.order`.

## Requisiti

- Drag handle implicito sulla row (drag intera row)
- Visual feedback durante drag (highlight drop zone)
- Persistenza immediata
- L'ordine si riflette in MenuBarExtra

## Checklist

- [ ] `.onMove` su `ForEach` dentro `List`
- [ ] Closure `move` chiama `ProfileStore.reorder(profiles, from:to:)`
- [ ] `reorder` riassegna `order = index` per ogni profilo
- [ ] Test: drag profilo 1 → posizione 3 → riapri app → ordine persiste
- [ ] Verificare comportamento con MenuBarExtra aperto durante drag

## Note tecniche

- `List` su macOS supporta `.onMove` nativamente (richiede `EditMode` su iOS, non su macOS)
- Indici: `IndexSet` source + `Int` destination
