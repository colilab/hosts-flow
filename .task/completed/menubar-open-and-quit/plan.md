# Plan: MenuBar — Rifinire "Apri Host Flow" e "Esci"

**Date:** 2026-05-11
**Type:** feature

## Original prompt
Combina due task in uno solo:
- `26-menubar-open-main.md` — rifinire la voce "Apri Host Flow" perché riapra anche la finestra chiusa, con icona `macwindow`.
- `27-menubar-quit.md` — rifinire la voce "Esci" con icona `power` e shortcut `⌘Q`. La label resta "Esci" (preferenza utente).

## Summary
Allineare i due bottoni di footer del popover menubar alle specifiche: icone SF Symbol, shortcut tastiera ⌘Q sulla voce Esci, e fix dell'apertura finestra quando il `WindowGroup` è stato distrutto (chiusa) — passando da `NSApp.windows.first` a `openWindow(id:)` con `WindowGroup(id: "main")`.

## Steps
1. [ ] `HostFlow/App/HostFlowApp.swift` — assegnare `WindowGroup(id: "main") { ContentView()... }`.
2. [ ] `HostFlow/Views/MenuBar/MenuBarView.swift` — aggiungere `@Environment(\.openWindow) private var openWindow` a `MenuBarView` e sostituire l'action del bottone "Apri Host Flow":
   - prima: `NSApp.activate(...)` + `NSApp.windows.first?.makeKeyAndOrderFront(nil)`
   - dopo: `NSApp.activate(ignoringOtherApps: true)` + `openWindow(id: "main")`
3. [ ] `HostFlow/Views/MenuBar/MenuBarView.swift` — usare `Label("Apri Host Flow", systemImage: "macwindow")` come content del bottone (con allineamento coerente al layout attuale).
4. [ ] `HostFlow/Views/MenuBar/MenuBarView.swift` — sul bottone "Esci":
   - sostituire `Text("Esci")` con `Label("Esci", systemImage: "power")`
   - aggiungere `.keyboardShortcut("q", modifiers: .command)`

## Out of scope
- Rinominare "Esci" in "Esci da Host Flow" (utente preferisce "Esci").
- Cambi alla voce "Impostazioni..." e agli altri bottoni esistenti.
- Persistenza dello stato finestra tra sessioni.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-11

**Resolution:** WindowGroup id="main" + openWindow per riaprire la finestra; icone macwindow/power + shortcut ⌘Q sui due bottoni footer. Build OK.
