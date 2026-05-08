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

---

**Status:** SPLIT — 2026-05-08

Suddiviso in 4 sub-task per gestione incrementale. Vedi:
- `19a-hosts-helper-target.md` — scaffolding helper (target XcodeGen, protocollo XPC, listener skeleton, plist template)
- `19b-hosts-helper-signing.md` — Ed25519 manifest signing pipeline + helper-side caller verification
- `19c-hosts-helper-installer.md` — privileged install/uninstall via `AuthorizationServices` + `launchctl bootstrap`
- `19d-hosts-helper-client.md` — `NSXPCConnection` client lato app + replace `HostsFileManager.write` + onboarding UI

**Decisione architetturale (vedi changelog):** strada B2 — daemon launchd installato con sudo iniziale + verifica caller via Ed25519-signed CDHash manifest (no Apple Developer Team ID richiesto).
