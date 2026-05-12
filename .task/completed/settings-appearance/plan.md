# Plan: Settings — Appearance (system/light/dark)

**Date:** 2026-05-12
**Type:** feature

## Summary

Picker segmented in Settings per scegliere appearance (System/Light/Dark). Override applicato a tutte le scene (`Window`, `MenuBarExtra`, `Settings`) via `.preferredColorScheme`. Cambio live, persistenza in `UserDefaults` (già presente).

## Steps

1. [x] Aggiungere `var colorScheme: ColorScheme?` a `AppearanceMode` (nil per `.system`) — `HostFlow/Stores/AppSettings.swift`
2. [x] Aggiungere computed `var preferredColorScheme: ColorScheme?` a `AppSettings` — `HostFlow/Stores/AppSettings.swift`
3. [x] Importare `SwiftUI` in `AppSettings.swift` per esporre `ColorScheme`
4. [x] Applicare `.preferredColorScheme(appSettings.preferredColorScheme)` su `Window`, `MenuBarExtra` popover, e `Settings` — `HostFlow/App/HostFlowApp.swift`
5. [x] Build verifica
6. [x] Test live: switch System/Light/Dark → tutte le finestre seguono, persistenza ok

## Out of scope

- Modifier sul `MenuBarLabel` (l'icona segue il menubar di sistema)
- Audit completo dark mode per altre view → task `32-darkmode-audit`
- Icone dedicate dark mode → task `33-darkmode-icons`

## Open questions

- Nessuna
