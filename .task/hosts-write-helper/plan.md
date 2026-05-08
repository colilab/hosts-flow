# Plan: /etc/hosts — Privileged helper (XPC)

**Date:** 2026-05-08
**Type:** feature

## Original prompt
> # Task: /etc/hosts — Privileged helper (XPC)
>
> ## Obiettivo
>
> Creare un helper privilegiato che esegue la scrittura di `/etc/hosts` per conto dell'app principale (sandboxed), comunicando via XPC.
>
> ## Requisiti
>
> - Helper installato via `SMAppService.daemon` (macOS 13+) o `SMJobBless` (legacy)
> - Bundle helper separato: `com.colilab.hostflow.helper`
> - Protocollo XPC con `writeHosts(content: String) async throws`
> - Code signing required (anche dev) — App ID + Helper ID con Team ID
> - Fallback: se helper non disponibile, mostra errore
>
> ## Checklist
>
> - [ ] Nuovo target in `project.yml`: `HostFlowHelper` (Command Line Tool)
> - [ ] Protocollo `HostFlowHelperProtocol` condiviso (Swift package o file shared)
> - [ ] `XPCListener` nel helper main
> - [ ] Embed helper in `Contents/Library/LaunchDaemons/` del bundle app
> - [ ] `SMAppService.daemon(plistName:)` registration in app
> - [ ] Plist daemon con `MachServices` key
> - [ ] Connection setup `NSXPCConnection(machServiceName:)` lato app
> - [ ] Helper esegue write atomico su `/etc/hosts`
>
> ## Note tecniche
>
> - Helper deve essere root: `User: root` nel plist
> - Code signing requirements: helper deve verificare che il chiamante sia firmato col Team ID corretto
> - Documentazione Apple: "Updating your helper tool" + sample `EvenBetterAuthorizationSample`
>
> ---
>
> **Status:** SPLIT — 2026-05-08
>
> Suddiviso in 4 sub-task per gestione incrementale. Vedi:
> - `19a-hosts-helper-target.md` — scaffolding helper (target XcodeGen, protocollo XPC, listener skeleton, plist template)
> - `19b-hosts-helper-signing.md` — Ed25519 manifest signing pipeline + helper-side caller verification
> - `19c-hosts-helper-installer.md` — privileged install/uninstall via `AuthorizationServices` + `launchctl bootstrap`
> - `19d-hosts-helper-client.md` — `NSXPCConnection` client lato app + replace `HostsFileManager.write` + onboarding UI
>
> **Decisione architetturale (vedi changelog):** strada B2 — daemon launchd installato con sudo iniziale + verifica caller via Ed25519-signed CDHash manifest (no Apple Developer Team ID richiesto).

## Summary
Introduce un helper privilegiato (`com.colilab.hostflow.helper`) che riceve via XPC la richiesta di scrittura di `/etc/hosts` dall'app principale e la esegue come root. La feature è suddivisa in 4 sub-task incrementali (scaffolding, signing manifest, installer privilegiato, client XPC + UI onboarding), con verifica del chiamante basata su CDHash firmato Ed25519 invece che Team ID Apple Developer (strada B2).

## Steps
1. [x] **a — Scaffolding helper**: nuovo target `HostFlowHelper` (Command Line Tool) in `project.yml`, protocollo `HostFlowHelperProtocol` condiviso, `XPCListener` skeleton nel main del helper, template plist launchd con `MachServices` + `User: root` — `project.yml`, `HostFlowHelper/`, `Shared/HostFlowHelperProtocol.swift`
2. [ ] **b — Signing pipeline (Ed25519)**: script di build che genera manifest firmato col CDHash dell'app, helper verifica al runtime che il chiamante corrisponda al manifest firmato — `Scripts/sign-manifest.sh`, `HostFlowHelper/CallerVerification.swift`
3. [ ] **c — Installer privilegiato**: install/uninstall via `AuthorizationServices` + `launchctl bootstrap`, copia helper in `/Library/PrivilegedHelperTools/` e plist in `/Library/LaunchDaemons/` — `HostFlow/Helpers/HelperInstaller.swift`
4. [ ] **d — Client XPC + UI**: `NSXPCConnection(machServiceName:)` lato app, sostituzione di `HostsFileManager.write` con chiamata XPC `writeHosts`, UI di onboarding che richiede installazione helper al primo avvio o quando assente, gestione errori (helper mancante / connessione fallita) — `HostFlow/Helpers/HostsFileManager.swift`, `HostFlow/Views/Onboarding/HelperInstallView.swift`

## Out of scope
- Notarization e distribuzione App Store (la strada B2 evita Team ID; la sandbox potrebbe restare disabilitata)
- Watch esterno di `/etc/hosts` (modifiche fatte da terzi) — task `23-hosts-watch-external`
- Authorization rights granulari (un solo right install/uninstall per ora) — eventuale espansione in `20-hosts-authorization`
- Migrazione futura a `SMAppService.daemon` puro (al momento installer custom via launchctl)

## Open questions
- Nessuna — i dettagli implementativi vivono nei 4 file di sub-task:
- @.task/hosts-write-helper/a-hosts-helper-target.md
- @.task/hosts-write-helper/b-hosts-helper-signing.md
- @.task/hosts-write-helper/c-hosts-helper-installer.md
- @.task/hosts-write-helper/d-hosts-helper-client.md
