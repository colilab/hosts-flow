# Task: /etc/hosts — Lettura + parsing blocco gestito

## Obiettivo

Leggere `/etc/hosts` e identificare il blocco gestito da Host Flow (delimitato dai marker), restituendo il contenuto pre/post + blocco.

## Requisiti

- Marker: `# --- Host Flow Start ---` / `# --- Host Flow End ---`
- Tollerante: se i marker mancano, blocco vuoto + flag "needs init"
- No modifica del file durante read
- Encoding UTF-8

## Checklist

- [ ] Struct `HostsFileContent { let preBlock: String; let block: String?; let postBlock: String }`
- [ ] `HostsFileManager.read() throws -> HostsFileContent`
- [ ] Implementazione: leggi file, splitta su marker (regex o componentsSeparatedBy)
- [ ] Caso 1 marker presente, l'altro no → throw `.malformedBlock`
- [ ] Caso entrambi assenti → `block = nil`, contenuto intero in `preBlock`
- [ ] Test unit con mock content

## Note tecniche

- Lettura `/etc/hosts` è world-readable, non richiede privilegi
- Errori file: `HostsFileError.notReadable`, `.malformedBlock`, `.encodingFailed`

---

**Completed:** 2026-05-07

**Resolution:** `HostsFileManager.read()` ora restituisce `HostsFileContent` strutturato (preBlock + block? + postBlock). Aggiunto enum `HostsFileError` (notReadable / malformedBlock / encodingFailed) con messaggi IT. Parser tollerante per marker assenti, throw su marker orfano.
