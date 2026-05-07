# Task: /etc/hosts — Privileged helper (XPC)

## Obiettivo

Creare un helper privilegiato che esegue la scrittura di `/etc/hosts` per conto dell'app principale (sandboxed), comunicando via XPC.

## Requisiti

- Helper installato via `SMAppService.daemon` (macOS 13+) o `SMJobBless` (legacy)
- Bundle helper separato: `com.colilab.hostflow.helper`
- Protocollo XPC con `writeHosts(content: String) async throws`
- Code signing required (anche dev) — App ID + Helper ID con Team ID
- Fallback: se helper non disponibile, mostra errore

## Checklist

- [ ] Nuovo target in `project.yml`: `HostFlowHelper` (Command Line Tool)
- [ ] Protocollo `HostFlowHelperProtocol` condiviso (Swift package o file shared)
- [ ] `XPCListener` nel helper main
- [ ] Embed helper in `Contents/Library/LaunchDaemons/` del bundle app
- [ ] `SMAppService.daemon(plistName:)` registration in app
- [ ] Plist daemon con `MachServices` key
- [ ] Connection setup `NSXPCConnection(machServiceName:)` lato app
- [ ] Helper esegue write atomico su `/etc/hosts`

## Note tecniche

- Helper deve essere root: `User: root` nel plist
- Code signing requirements: helper deve verificare che il chiamante sia firmato col Team ID corretto
- Documentazione Apple: "Updating your helper tool" + sample `EvenBetterAuthorizationSample`
