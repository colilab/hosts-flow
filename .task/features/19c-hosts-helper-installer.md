# Task: Helper privilegiato — Installer + write atomico

## Obiettivo

Logica di install/uninstall del daemon su sistema (richiede prompt admin una volta) + implementazione reale di `writeHosts` nel daemon che esegue il write atomico su `/etc/hosts` come root.

## Requisiti

- Install: copia helper binary in `/Library/PrivilegedHelperTools/`, plist in `/Library/LaunchDaemons/`, chown root:wheel, chmod, `launchctl bootstrap system`
- Una sola password admin all'install
- Uninstall: `launchctl bootout`, rm dei file
- Write atomico in `HelperService.writeHosts`: backup + temp file + atomic rename + chmod 644 + chown root:wheel
- Errori loggati in `~/Library/Logs/HostFlow/helper.log` (creato con privilegi normali — l'helper come root può scrivere ovunque, ma logging in user dir per visibilità)

## Checklist

- [ ] `HostFlow/App/HelperInstaller.swift` (lato app):
  - `func install() async throws` — prompt admin via `AuthorizationCreate` + `AuthorizationExecuteWithPrivileges` con script bash di install
  - `func uninstall() async throws` — analogo con script di rimozione
  - `var isInstalled: Bool { FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.colilab.hostflow.helper.plist") }`
- [ ] Script bash inline nell'app (passato a privileged process):
  ```bash
  cp <app>/Contents/Library/LaunchDaemons/HostFlowHelper /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
  chown root:wheel /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
  chmod 755 /Library/PrivilegedHelperTools/com.colilab.hostflow.helper
  cp <app>/Contents/Library/LaunchDaemons/com.colilab.hostflow.helper.plist /Library/LaunchDaemons/
  chown root:wheel /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
  chmod 644 /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
  launchctl bootstrap system /Library/LaunchDaemons/com.colilab.hostflow.helper.plist
  ```
- [ ] `HelperService.writeHosts(content:reply:)`: implementazione reale
  - verifica caller (vedi 19b) — se non autorizzato `reply(.unauthorizedCaller)` e return
  - leggi `/etc/hosts` (per backup)
  - scrivi backup in `/etc/hosts.hostflow.bak` (overwrite ogni volta — bisognerebbe? sì per ora)
  - scrivi `content` in `/etc/hosts.hostflow.tmp` con encoding UTF-8
  - chmod 644 + chown root:wheel sul tmp
  - `FileManager.replaceItem(at:withItemAt:)` per atomic rename → `/etc/hosts`
  - reply(nil) on success, reply(error) on failure
- [ ] `HelperError` enum (in shared file): `.unauthorizedCaller`, `.fsError(String)`, `.invalidContent`
- [ ] Logging in `HelperService`: scrive su `~/Library/Logs/HostFlow/helper.log` (path absolute con $HOME del caller? complesso da root). Per ora: `os_log` su system log con subsystem `com.colilab.hostflow.helper`.
- [ ] Build verifica + test manuale install: bottone fittizio temporaneo in app → install → verifica daemon attivo via `launchctl list | grep hostflow` → uninstall

## Note tecniche

- `AuthorizationExecuteWithPrivileges` è deprecata ma funziona ancora su macOS 14. Alternativa moderna: passare a un command line `osascript -e 'do shell script ... with administrator privileges'` che fa la stessa cosa con UI Apple-native. Verificare quale dei due funziona meglio in app GUI sandboxed (probabilmente serve sandbox-off, vedi punto sotto)
- **Sandbox dell'app principale**: per chiamare `AuthorizationExecuteWithPrivileges` o `osascript with admin` serve disabilitare `app-sandbox` nelle entitlements. Decisione architetturale (B2 accept this trade-off)
- `FileManager.replaceItem` è atomic via syscall `rename(2)`
- Backup `.hostflow.bak` non versionato — overwrite ad ogni write per semplicità

## Out of scope

- Rollback automatico su errore (bisognerebbe restore da backup) — semplice followup
- File watcher esterno per detect manual edit → task `23-hosts-watch-external`
- Trigger debounced lato app → task `22-hosts-trigger`
- UI install/uninstall in Settings → 19d
