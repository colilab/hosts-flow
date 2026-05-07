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

- [ ] Pre-prompt alert: "Host Flow ha bisogno di scrivere su /etc/hosts. Verrà richiesta l'autorizzazione admin."
- [ ] `SMAppService.daemon(...).register()` async
- [ ] Gestione errore `.requiresApproval` → guida utente a System Settings → Login Items
- [ ] Stato `HelperStatus` enum: `.notInstalled`, `.installed`, `.requiresApproval`, `.error(Error)`
- [ ] Esposto in `AppSettings` per UI
- [ ] Bottone "Disinstalla helper" in Settings con conferma

## Note tecniche

- `SMAppService.daemon` su macOS 13+: l'utente deve approvare in System Settings → General → Login Items
- Status check via `SMAppService.daemon(plistName:).status`
- Su downgrade compatibilità: `SMJobBless` (deprecated ma funziona) come fallback
