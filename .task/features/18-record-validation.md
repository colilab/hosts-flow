# Task: Record — Warning duplicati hostname

## Obiettivo

Mostrare un warning visivo (non blocking) quando un hostname è duplicato all'interno dello stesso profilo o tra profili attivi.

## Requisiti

- Non blocca il salvataggio (è valido avere duplicati per casi avanzati)
- Icona warning SF Symbol `exclamationmark.triangle` con tooltip
- Check effettuato all'apertura del profilo + dopo edit/add

## Checklist

- [ ] Computed `duplicatedHostnames: Set<String>` in `ProfileDetailView`
- [ ] Group by hostname (case-insensitive) → keep quelli con count > 1
- [ ] Aggiungere icona warning in colonna hostname se duplicato
- [ ] Tooltip: "Hostname duplicato — l'ultimo record attivo prevarrà"
- [ ] Estendere check ai profili attivi (cross-profile duplicate)

## Note tecniche

- `.help("...")` per tooltip
- Cross-profile: query `Profile` con `isActive == true` e flatten records
