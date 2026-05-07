# Task: /etc/hosts — Watch e sync Default da edit esterni

## Obiettivo

Monitorare `/etc/hosts` e, se modificato manualmente fuori dall'app (es. l'utente edita con `vim`), aggiornare automaticamente il profilo Default per riflettere il contenuto fuori dal blocco Host Flow.

## Requisiti

- File watcher sul path `/etc/hosts` (FSEvents o `DispatchSource.makeFileSystemObjectSource`)
- Re-parse della sezione **fuori** dal blocco Host Flow → aggiorna record di Default
- Distinguere modifiche nostre vs esterne via `lastWriteAt` di `ProfileStore`:
  - file mtime entro ±2s da `lastWriteAt` → ignora (siamo stati noi)
  - oltre → considera edit esterno → sync
- Default è `isReadOnly` ma il watcher aggiorna direttamente lo store (bypass UI guard, è la sua specifica funzione)
- Nessun loop: dopo il sync, il successivo writeHosts NON deve riscrivere il file (contenuto unmanaged identico)
- Stop/start watcher: pausa durante write nostro per evitare race

## Checklist

- [ ] `HostsFileWatcher` class con `start()` / `stop()`
- [ ] `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask: [.write, .delete, .rename, .extend])`
- [ ] Handler riceve evento → debounce 300ms → check mtime vs `profileStore.lastWriteAt`
- [ ] Se edit esterno: legge file → parsa unmanaged section → diff con record Default
- [ ] Diff strategy:
  - record presenti nel file e non in Default → add
  - record in Default e non nel file → remove
  - record con stesso `(ip, hostname)` ma diverso `isEnabled` → update
- [ ] Pre-write: chiama `watcher.pause()` in `hosts-write-atomic` flow → resume dopo
- [ ] Re-attach watcher su file delete/rename (es. atomic replace cambia il file descriptor)
- [ ] Avvio watcher in `HostFlowApp` `.task` dopo `seedIfNeeded`
- [ ] Stop watcher su app terminate

## Note tecniche

- File descriptor: `open("/etc/hosts", O_EVTONLY)` per monitor senza lock
- Atomic replace (rename) invalidates il fd → watcher deve riprendere `open` su evento `.delete` / `.rename`
- Edge case: utente sostituisce `/etc/hosts` con file completamente diverso senza marker → block vuoto, Default = tutto il contenuto
- Edge case: utente cancella i marker → trattare come "nessun blocco gestito", Default = tutto il file; il prossimo write rimetterà i marker
- Loop prevention: il diff deve essere strutturale, non textual — riformattazione spazi non deve generare update
- Update Default record direttamente via `ModelContext` — il flag `isReadOnly` è solo UI-level, non blocca scritture programmatiche
