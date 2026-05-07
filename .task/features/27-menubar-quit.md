# Task: MenuBar — Voce Esci

## Obiettivo

Voce "Esci da Host Flow" in fondo al popover che termina l'app.

## Requisiti

- Posizione: in fondo, dopo Settings + separatore
- Keyboard shortcut: `⌘Q` visibile
- Action: `NSApp.terminate(nil)`

## Checklist

- [ ] `Divider` prima della voce
- [ ] Bottone "Esci" con SF Symbol `power`
- [ ] `.keyboardShortcut("q", modifiers: .command)` (visualizzato `⌘Q`)
- [ ] Action: `NSApplication.shared.terminate(nil)`

## Note tecniche

- macOS standard: comando "Esci da App" si trova in fondo a tutti i menu app
- L'helper privilegiato resta in esecuzione anche dopo quit (gestito dal sistema)
