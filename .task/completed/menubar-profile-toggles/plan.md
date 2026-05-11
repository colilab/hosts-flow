# Plan: MenuBar — Lista profili con toggle

**Date:** 2026-05-11
**Type:** feature

## Original prompt
> # Task: MenuBar — Lista profili con toggle
>
> ## Obiettivo
>
> Popover MenuBarExtra mostra la lista profili (sortati per `order`) con un Toggle per ciascuno, sincronizzato con la finestra principale.
>
> ## Requisiti
>
> - Stesso `ModelContainer` della finestra principale (già configurato)
> - Toggle live: cambio nel menu bar → aggiornamento immediato in sidebar
> - Layout: row con nome profilo + toggle. Nome allineato a sx e toggle a dx (come sidebar)
> - Empty state: "Nessun profilo. Crea il primo dalla finestra principale."
>
> ## Checklist
>
> - [ ] `MenuBarView` usa `@Query(sort: \Profile.order)` su `Profile`
> - [ ] ForEach con HStack: `Text(profile.name)` + `Spacer()` + record count badge + `Toggle`
> - [ ] `Toggle` con `.toggleStyle(.switch)` `.controlSize(.small)`
> - [ ] Width container: 280pt
> - [ ] Empty state con icona `tray` SF Symbol
> - [ ] Trigger `writeHosts` su toggle (vedi 05-hosts-trigger)
>
> ## Note tecniche
>
> - `MenuBarExtra` con `.menuBarExtraStyle(.window)` permette layout SwiftUI completo
> - Dimensioni popover: `.frame(width: 280)` sul root view

## Summary
Rifinire `MenuBarView` per allinearla alla specifica: layout riga in stile sidebar (Text + Spacer + Toggle labelsHidden), width 280pt, empty state con icona `tray` e copy completo. Nessun badge contatore. ControlSize Toggle resta `.mini` per coerenza con la sidebar.

## Steps
1. [ ] Cambiare width root da 220 a 280 — `HostFlow/Views/MenuBar/MenuBarView.swift`
2. [ ] Sostituire empty state con VStack (icona `tray` + testo "Nessun profilo. Crea il primo dalla finestra principale.") — `HostFlow/Views/MenuBar/MenuBarView.swift`
3. [ ] Refactor `MenuBarProfileRow` al layout `HStack { Text(name) + lock-icon-if-readonly + Spacer + Toggle(labelsHidden) }` (come `ProfileRowView` della sidebar) mantenendo `.toggleStyle(.switch)` `.controlSize(.mini)` e `onChange` esistente — `HostFlow/Views/MenuBar/MenuBarView.swift`

## Out of scope
- Record count badge (escluso esplicitamente)
- Modifiche alla `SidebarView`
- Modifiche al flusso `scheduleWrite` (già presente)

## Open questions
- Nessuna.

---

**Completed:** 2026-05-11

**Resolution:** Adjusted `MenuBarView` to 280pt width, added `tray` empty state, refactored row to sidebar-style layout (Text + Spacer + labelsHidden Toggle). Build OK.
