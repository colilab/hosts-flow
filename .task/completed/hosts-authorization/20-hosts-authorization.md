# Task: /etc/hosts — Flow autorizzazione admin

## Obiettivo

Al primo tentativo di scrittura `/etc/hosts`, mostrare il prompt admin di sistema, installare l'helper, salvare lo stato in modo che le successive scritture siano silenziose.

## Requisiti

- Prompt admin nativo (NSWorkspace o `SMAppService` flow)
- One-time setup: dopo install, l'helper resta installato
- Stato "helper installed" tracciato (UserDefaults o `SMAppService.status`)
- Onboarding: alert spiega perché serve il privilegio prima di mostrare il prompt
- Disinstallazione helper su richiesta utente (Settings)

## Checklist

- [x] Pre-prompt alert: "Host Flow ha bisogno di scrivere su /etc/hosts. Verrà richiesta l'autorizzazione admin." (già coperto da `HelperOnboardingSheet`)
- [ ] ~~`SMAppService.daemon(...).register()` async~~ — non applicabile (path osascript+Ed25519, no Apple Developer Team ID)
- [ ] ~~Gestione errore `.requiresApproval`~~ — non applicabile (idem)
- [x] Stato `HelperStatus` enum: `.notInstalled`, `.installed`, `.error(Error)` (`.requiresApproval` skippato)
- [x] Esposto in `AppSettings` per UI
- [x] Bottone "Disinstalla helper" in Settings con conferma

## Note tecniche

- Path scelto in fase di implementazione (vedi `c-hosts-helper-installer.md`): osascript `do shell script with administrator privileges` + manifest Ed25519 firmato per caller verification. `SMAppService.daemon` richiederebbe Team ID Apple Developer, esplicitamente fuori scope.
- `HelperInstaller` come singleton `@Observable`: `status` mutata da `install()`/`uninstall()`, errori catturati nel caso `.error(Error)`.
- `refreshStatus()` chiamato prima del check in `ProfileStore.writeHosts` per gestire disinstallazioni esterne.

---

**Completed:** 2026-05-09

**Resolution:** `HelperStatus` enum (`.notInstalled`/`.installed`/`.error(Error)`) introdotto in `HelperInstaller.swift`. `HelperInstaller` ora singleton `.shared` con `status` osservabile mutata da install/uninstall (errori catturati nel caso `.error`). `AppSettings` espone `helperInstaller` + `helperStatus` per accesso UI. `ContentView`, `HelperSettingsSection`, `ProfileStore.writeHosts` migrati alla singleton (no più istanze locali). `HelperSettingsSection` switch-driven sullo status e disinstallazione gated da `.confirmationDialog` nativo. `.requiresApproval` non implementato: non applicabile al flow osascript scelto.
