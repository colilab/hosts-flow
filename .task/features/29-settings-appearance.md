# Task: Settings — Appearance (system/light/dark)

## Obiettivo

Picker in Settings per scegliere appearance dell'app: System (default), Light, Dark. Override applicato a tutte le scene.

## Requisiti

- Picker segmented con 3 opzioni
- Persistenza in UserDefaults (già impostata)
- Override colorScheme applicato a `WindowGroup`, `MenuBarExtra`, `Settings`
- Cambio live senza restart

## Checklist

- [ ] `AppearanceMode` enum già esistente — verificare casi `.system`, `.light`, `.dark`
- [ ] Computed `var preferredColorScheme: ColorScheme?` (nil per system)
- [ ] In `HostFlowApp.body`: `.preferredColorScheme(appSettings.preferredColorScheme)` su ogni scene
- [ ] Picker in `SettingsView` con `.pickerStyle(.segmented)`
- [ ] Test: switch tra system/light/dark → tutte le finestre seguono

## Note tecniche

- `.preferredColorScheme(nil)` = segui sistema
- MenuBarExtra popover prende anche modifier (testare)
