# Task: MenuBar — Apri finestra principale

## Obiettivo

Voce "Apri Host Flow" nel popover menu bar che porta in primo piano la finestra principale (creandola se chiusa).

## Requisiti

- Bottone con icona `macwindow` SF Symbol
- Funziona sia se finestra è chiusa, minimizzata, o in background
- Activate app + bring to front

## Checklist

- [ ] Bottone in `MenuBarView` con etichetta "Apri Host Flow"
- [ ] Action: `NSApp.activate(ignoringOtherApps: true)` + apri WindowGroup
- [ ] Per riaprire WindowGroup chiusa: `openWindow` action o `NSApp.windows.first?.makeKeyAndOrderFront`
- [ ] Su click → chiudi popover + apri finestra
- [ ] Test: chiudi finestra principale → click voce → finestra riappare

## Note tecniche

- `@Environment(\.openWindow) var openWindow` (macOS 13+)
- Identificare WindowGroup con `.id("main")` o `WindowGroup(id: "main")`
- Se `LSUIElement = true`, no Dock icon → `NSApp.activate` essenziale
