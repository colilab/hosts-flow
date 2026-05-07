# Task: MenuBar — Lista profili con toggle

## Obiettivo

Popover MenuBarExtra mostra la lista profili (sortati per `order`) con un Toggle per ciascuno, sincronizzato con la finestra principale.

## Requisiti

- Stesso `ModelContainer` della finestra principale (già configurato)
- Toggle live: cambio nel menu bar → aggiornamento immediato in sidebar
- Layout: row con nome profilo + count record + toggle
- Empty state: "Nessun profilo. Crea il primo dalla finestra principale."

## Checklist

- [ ] `MenuBarView` usa `@Query(sort: \Profile.order)` su `Profile`
- [ ] ForEach con HStack: `Text(profile.name)` + `Spacer()` + record count badge + `Toggle`
- [ ] `Toggle` con `.toggleStyle(.switch)` `.controlSize(.small)`
- [ ] Width container: 280pt
- [ ] Empty state con icona `tray` SF Symbol
- [ ] Trigger `writeHosts` su toggle (vedi 05-hosts-trigger)

## Note tecniche

- `MenuBarExtra` con `.menuBarExtraStyle(.window)` permette layout SwiftUI completo
- Dimensioni popover: `.frame(width: 280)` sul root view
