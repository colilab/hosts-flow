# Task: Settings — Launch at login

## Obiettivo

Toggle in Settings che registra/deregistra l'app come login item via `SMAppService.mainApp`, persistente tra riavvii.

## Requisiti

- `SMAppService.mainApp.register()` / `unregister()` async
- Stato letto da `SMAppService.mainApp.status`
- UI sincronizzata con stato reale (non solo UserDefaults)
- Errore registrazione → Alert con dettagli

## Checklist

- [x] In `AppSettings`: `var launchAtLogin: Bool` con setter che chiama `register/unregister`
- [x] Init: leggi `SMAppService.mainApp.status` → `launchAtLogin = (status == .enabled)`
- [x] Toggle in `SettingsView` bindato a `appSettings.launchAtLogin`
- [x] Error handling: catch + show Alert "Impossibile attivare avvio automatico: \(error.localizedDescription)"
- [ ] Test: enable → riavvia mac → verifica autostart

## Note tecniche

- `SMAppService.mainApp` (macOS 13+) — non richiede separato target, usa il main bundle
- Status enum: `.notRegistered`, `.enabled`, `.requiresApproval`, `.notFound`
- Su `.requiresApproval`: link a System Settings → General → Login Items
