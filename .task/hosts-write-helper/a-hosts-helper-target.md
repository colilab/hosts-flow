# Task: Helper privilegiato — Target & protocollo XPC (skeleton)

## Obiettivo

Scaffolding del binario helper privilegiato: nuovo target `HostFlowHelper` (Command Line Tool, Swift), protocollo XPC condiviso con l'app, `NSXPCListener` di base che accetta connessioni e implementa lo stub di `writeHosts(content:reply:)`, plist template del daemon. **Nessuna logica reale di scrittura, nessun install, nessuna verifica caller** — solo il telaio compilabile.

## Requisiti

- Nuovo target `HostFlowHelper` aggiunto in `project.yml` (Command Line Tool, no UI, deployment target macOS 14)
- Bundle ID: `com.colilab.hostflow.helper`
- Protocollo `HostFlowHelperProtocol` come `@objc protocol` in file shared (compilato da entrambi i target)
- `main.swift` del helper: configura `NSXPCListener`, impone delegate, run forever
- Plist template `com.colilab.hostflow.helper.plist` in `HostFlow/Helper/Resources/` con `Label`, `MachServices`, `ProgramArguments`, `RunAtLoad`, `KeepAlive`
- Embed plist + helper binary nelle risorse del bundle app (per il futuro installer)

## Checklist

- [ ] Aggiungere target `HostFlowHelper` in `project.yml` (CLI, sources `HostFlow/Helper/`)
- [ ] Creare cartella `HostFlow/Helper/`
- [ ] `HostFlow/Shared/HostFlowHelperProtocol.swift` con `@objc public protocol HostFlowHelperProtocol { func writeHosts(content: String, reply: @escaping (Error?) -> Void) }`
- [ ] Aggiungere il file shared a entrambi i target (`HostFlow` e `HostFlowHelper`) in `project.yml`
- [ ] `HostFlow/Helper/main.swift` con `NSXPCListener(machServiceName: "com.colilab.hostflow.helper")`, `Listener.delegate = ...`, `Listener.resume()`, `RunLoop.main.run()`
- [ ] `HostFlow/Helper/HelperListenerDelegate.swift` — `NSXPCListenerDelegate` che configura `exportedInterface` + `exportedObject` (stub)
- [ ] `HostFlow/Helper/HelperService.swift` — implementa `HostFlowHelperProtocol`, `writeHosts` per ora ritorna `nil` (success no-op)
- [ ] `HostFlow/Helper/Resources/com.colilab.hostflow.helper.plist` template con tutte le chiavi necessarie
- [ ] Embed phase: copiare helper binary in `HostFlow.app/Contents/Library/LaunchDaemons/` o `Contents/Library/HostFlowHelper`
- [ ] `xcodegen generate` + build verifica entrambi i target (app + helper) compilano

## Note tecniche

- `@objc` requirement: `NSXPCConnection` lavora con interfacce Obj-C runtime
- Reply handler asincrono richiesto per chiamate XPC che possono fallire
- Helper binary va in `Contents/Library/LaunchDaemons/` (convenzione SMAppService) o `Contents/MacOS/HostFlowHelper` con plist che lo punta — preferibile la prima per compat futura
- Dev signing: ad-hoc OK in questa fase (nessuna registrazione daemon ancora)

## Out of scope

- Logica `/etc/hosts` write reale → c
- Verifica caller via Ed25519 → b
- Installazione/registrazione daemon → c
- Client app-side → d
