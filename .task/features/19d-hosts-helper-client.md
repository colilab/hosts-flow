# Task: Helper privilegiato — Client app + onboarding UI

## Obiettivo

Lato app: client `NSXPCConnection` che parla col daemon, sostituzione del path "scrittura diretta" in `HostsFileManager.write` con la chiamata XPC, modale di onboarding al primo write che spiega il prompt admin, e sezione Settings per stato/install/uninstall del helper.

## Requisiti

- `HostsXPCClient` usa `NSXPCConnection(machServiceName:options: .privileged)` con `remoteObjectInterface = NSXPCInterface(with: HostFlowHelperProtocol.self)`
- `HostsFileManager.write(profiles:)` ora chiama il client invece di scrivere diretto. Path "diretto" rimosso.
- Pre-flight: se `HelperInstaller.isInstalled == false`, mostra modale onboarding con bottone "Installa helper"
- Errori XPC propagati a UI come `Alert` nativo
- Settings → nuova sezione "Componente di sistema" con stato (installato / non installato) + bottoni Installa/Disinstalla

## Checklist

- [ ] `HostFlow/Helpers/HostsXPCClient.swift`:
  - lazy `connection: NSXPCConnection` con setup, `invalidationHandler`, `interruptionHandler`
  - `func writeHosts(_ content: String) async throws` — wrapper async/await su reply XPC
- [ ] Modificare `HostsFileManager.write(profiles:)` → `async throws`:
  - chiama `buildBlock` (esistente)
  - chiama `HostsXPCClient.shared.writeHosts(content)`
- [ ] Aggiornare `ProfileStore.writeHosts(context:)` → diventa `async`, chiama il manager async
- [ ] Aggiornare tutti i call site di `writeHosts` in views per usare `Task { await ... }`
- [ ] `HostFlow/Views/Onboarding/HelperOnboardingSheet.swift`:
  - mostrato se `!HelperInstaller.isInstalled` quando l'utente attiva il primo profilo
  - testo: "Host Flow ha bisogno di un componente di sistema per scrivere `/etc/hosts`. Installa una sola volta. Verrà chiesta la password admin."
  - Bottone "Installa" → chiama `HelperInstaller.install()` → su success dismiss
  - Bottone "Annulla" → dismiss senza install (write fallisce, profilo torna disabled)
- [ ] In `SettingsView`: nuova sezione "Componente di sistema":
  - LabeledContent "Stato" — "Installato" / "Non installato" (poll su appear)
  - Se non installato: bottone "Installa..."
  - Se installato: bottone "Disinstalla..." (.borderedProminent .tint(.red))
- [ ] Error handling: errori XPC → `Alert("Impossibile scrivere /etc/hosts", message: error.localizedDescription)`
- [ ] Build verifica + test E2E: install helper → toggle profilo attivo → verifica `/etc/hosts` aggiornato → disinstalla helper → toggle → vede modale onboarding di nuovo

## Note tecniche

- `NSXPCConnection` è stateful: una volta creata, riusa la stessa connection per chiamate successive
- `invalidationHandler` cleanup state quando il daemon muore o viene unloaded
- Gestione error: l'helper può rispondere con `NSError` via reply handler, non con `throw` Swift — convertire al caller
- Settings poll: usa `.task` modifier per refresh stato all'apertura della sezione

## Out of scope

- File watcher → task `23-hosts-watch-external`
- Debounce dei write → task `22-hosts-trigger`
- Reset blocco gestito → task `29-settings-reset-block`
- Logiche advanced di retry / backoff
