# Plan: /etc/hosts — Watch e sync Default da edit esterni

**Date:** 2026-05-11
**Type:** feature

## Original prompt
> Monitorare `/etc/hosts` e, se modificato manualmente fuori dall'app (es. l'utente edita con `vim`), aggiornare automaticamente il profilo Default per riflettere il contenuto fuori dal blocco Host Flow. Watcher con `DispatchSource.makeFileSystemObjectSource`, debounce 300ms, distinzione modifiche nostre vs esterne via `lastWriteAt`, diff strutturale per evitare loop, re-attach del fd su atomic replace.

## Summary
Aggiunge un componente `HostsFileWatcher` che monitora `/etc/hosts` con un `DispatchSourceFileSystemObject` su fd `O_EVTONLY`. Su evento debounciato (300ms) ri-parsa la sezione *fuori* dal blocco Host Flow e applica un diff set-based `(ip, hostname)` ai record del profilo Default, ricostruendo l'ordine dal file. Il watcher osserva `ProfileStore.isWritingHosts` per auto-pausarsi durante le scritture nostre (più check mtime±2s come backup) e si re-aggancia automaticamente al fd dopo eventi `.delete`/`.rename` (atomic replace) con backoff fino a 5s.

## Decisioni concordate
- **Avvio watcher:** in `ContentView.task` subito dopo `seedIfNeeded`.
- **Pause strategy:** il watcher osserva `ProfileStore.isWritingHosts`/`lastWriteAt` (Observation). Quando `isWritingHosts == true` la pipeline è pausata; quando torna `false` riprende. In aggiunta, un check mtime entro ±2s da `lastWriteAt` scarta l'evento (belt-and-suspenders).
- **Diff:** set-based su chiave `(ip, hostname)`. Per gli `add` si appendono in coda; l'ordine finale dei record di Default segue l'ordine del file (riordino esistenti + nuovi in coda). I record con stessa chiave ma `isEnabled` diverso vengono aggiornati in place.
- **Re-attach:** su `.delete`/`.rename` chiudo il fd, ritento `open(O_EVTONLY)` con backoff (50/100/200/500/1000/2000 ms, max ~5s); dopo riapertura forzo un sync immediato perché il contenuto può essere già cambiato.

## Steps
1. [ ] Estendi `ProfileStore` con due helper: `syncDefaultFromFile(context:)` che esegue il diff strutturale, e (se utile) `markExternalWrite()` no-op per future estensioni — file: `HostFlow/Stores/ProfileStore.swift`.
2. [ ] Aggiungi un metodo statico/utility `HostsFileParser.parseUnmanagedSection(_:) -> [ParsedHostRecord]` per parsare un contenuto raw isolando `preBlock + postBlock` (riusa logica esistente; espone una funzione che accetta `HostsFileContent`). File: `HostFlow/Helpers/HostsFileParser.swift`.
3. [ ] Crea `HostFlow/Helpers/HostsFileWatcher.swift`:
   - Classe `final class HostsFileWatcher` `@MainActor`.
   - API: `start(profileStore:context:)`, `stop()`.
   - Internamente: `fd: Int32 = -1`, `source: DispatchSourceFileSystemObject?`, `debounceTask: Task?`, `paused: Bool`.
   - `open("/etc/hosts", O_EVTONLY)` su queue dedicata `DispatchQueue(label: "hostflow.watcher")`.
   - eventMask: `[.write, .delete, .rename, .extend, .attrib]`.
   - `setEventHandler`: se `.delete`/`.rename` → `reopenWithBackoff()`; altrimenti `scheduleDebouncedSync()`.
   - `setCancelHandler`: `close(fd)`.
   - `scheduleDebouncedSync`: cancella task precedente, crea `Task { sleep 300ms; await MainActor.run { handleSync() } }`.
   - `handleSync()`: se `paused` o `isWritingHosts` → return. Legge mtime via `stat`; se `|mtime - lastWriteAt| <= 2s` → return. Altrimenti chiama `profileStore.syncDefaultFromFile(context:)`.
   - Osserva `isWritingHosts` via `withObservationTracking` (loop ricorsivo) per impostare `paused`.
   - `reopenWithBackoff`: chiude source corrente, ritenta open con backoff esponenziale fino a 5s; on success ricostruisce la source e triggera un sync immediato.
4. [ ] Implementa `ProfileStore.syncDefaultFromFile(context:)`:
   - Fetch del Profile con `isReadOnly == true` (Default).
   - `HostsFileManager.shared.read()` → `parseUnmanagedSection`.
   - Costruisce dict `current` di record per chiave `(ip, hostname)`.
   - Itera i parsed nel loro ordine:
     - se presente in `current`: aggiorna `isEnabled` se diverso, fissa `order` progressivo.
     - se assente: crea `HostRecord(ip, hostname, profile: default)` con `isEnabled` dal parse.
   - I rimanenti in `current` non visti → `context.delete`.
   - `try? context.save()`. **Non** chiama `scheduleWrite` (il file è già coerente).
5. [ ] Aggiungi `order` ai record se non già presente, o usa array `default.records` riassegnando — controlla `Models/HostRecord.swift` (se non c'è proprietà order, mantieni ordine via reinsert sequence).
6. [ ] Integra il watcher in `ContentView`:
   - `@State private var watcher = HostsFileWatcher()`
   - Nel `.task` esistente, dopo `store.seedIfNeeded(...)`: `watcher.start(profileStore: store, context: context)`.
   - In `.onDisappear` o tramite `ScenePhase` su `.background` non stoppare (vogliamo continuare mentre l'app è viva); stop su deinit del watcher è sufficiente.
7. [ ] Smoke test manuale:
   - Modifica `/etc/hosts` con `sudo vim` aggiungendo `1.2.3.4 test.local` fuori dal blocco → Default deve mostrare il nuovo record.
   - Commenta una riga `# 1.2.3.4 test.local` → record deve diventare `isEnabled = false`.
   - Cancella i marker → Default = tutto il file (no errori).
   - Toggle profilo dall'app → nessun loop di sync, nessun evento spurio.
   - `cat > /etc/hosts` con contenuto identico → nessun cambiamento ai record Default (diff strutturale).

## Out of scope
- Notifiche utente in-app per edit esterni rilevati.
- Conflict resolution UI (merge tra edit utente in-app e edit esterno concorrente).
- Watch su file diversi da `/etc/hosts`.
- Persistenza del flag "watcher abilitato" nelle Settings.
- Modifiche al protocollo XPC / Helper.

## Open questions
- Nessuna — le scelte aperte sono state risolte durante grilling.

---

**Completed:** 2026-05-11

**Resolution:** Added `HostsFileWatcher` using `DispatchSource` on `O_EVTONLY` fd with 300ms debounce, mtime±2s + `isWritingHosts` guards, exponential-backoff re-attach on rename/delete, and a set-based `(ip, hostname)` diff in `ProfileStore.syncDefaultFromFile`. Wired in `ContentView.task` after seed. Build passes.
