# Task: Seed iniziale profilo "Default" da /etc/hosts

## Obiettivo

Al primo avvio, se nessun profilo esiste, creare un profilo "Default" attivo popolato leggendo il contenuto reale di `/etc/hosts` (escludendo eventuale blocco Host Flow già presente). Questo cattura lo stato di sistema attuale dell'utente come base.

## Requisiti

- Eseguito una sola volta — idempotente (count profili = 0)
- Profilo creato come `isActive = true`, `order = 0`, **`isReadOnly = true`** (vedi task readonly-flag)
- Lettura `/etc/hosts` real (no privilegi richiesti per read)
- Parser ignora:
  - righe vuote
  - commenti puri (es. `# This file controls ...`)
  - blocco Host Flow esistente (tra marker, se presente da install precedente)
- Parser riconosce e importa:
  - record attivi: `127.0.0.1 localhost`, `::1 localhost`, `255.255.255.255 broadcasthost`
  - record commentati con pattern `# IP HOSTNAME` → importati come `isEnabled = false`
- Hostname multipli sulla stessa riga (`127.0.0.1 a.local b.local`) → 1 record per ciascun hostname

## Checklist

- [ ] Estensione `ProfileStore` con `func seedIfNeeded(context: ModelContext)`
- [ ] Query `Profile` count → se > 0, return early
- [ ] `HostsFileParser.parseSystemHosts() throws -> [HostRecord]`
  - leggi `/etc/hosts` (read-only, no helper richiesto)
  - skip righe nel blocco Host Flow (delimitato dai marker)
  - regex match: `^(#?\s*)?(\S+)\s+(\S+(?:\s+\S+)*)(\s+#.*)?$`
  - per ogni hostname nella riga: crea `HostRecord(ip, hostname, isEnabled: !commented)`
- [ ] Crea Profile "Default", `isActive = true`, `order = 0`, `isReadOnly = true`, attach record parsed
- [ ] Edge case: `/etc/hosts` contiene SOLO il blocco Host Flow → record vuoti ma profilo creato comunque (vuoto)
- [ ] Edge case: `/etc/hosts` non leggibile → log warning, crea Default vuoto, no crash
- [ ] Chiamata `seedIfNeeded` in `HostFlowApp` (es. `.task` modifier sulla root view)
- [ ] Test manuale: cancella SwiftData store → riapri app → Default contiene voci sistema reali

## Note tecniche

- File `/etc/hosts` è world-readable: `try String(contentsOfFile: "/etc/hosts", encoding: .utf8)` funziona da app sandboxed con `temporary-exception` già configurato
- Il parser è lo stesso usato per task 09-import-hosts-format → estrarre in `HostsFileParser` riusabile
- Dopo il seed, al primo `writeHosts` il blocco Host Flow rimpiazzerà le entry originali nel file (le record originali sono ora in SwiftData → riscritte dentro al blocco gestito)
- **Importante**: il Default `isActive = true` garantisce che lo stato visibile in `/etc/hosts` non cambi dopo il seed (i record vengono spostati dal contenuto raw al blocco Host Flow ma sono gli stessi)
- `isReadOnly = true` impedisce modifiche accidentali alle entry di sistema; l'utente che vuole modificare deve duplicare (vedi task duplicate / context-menu)
