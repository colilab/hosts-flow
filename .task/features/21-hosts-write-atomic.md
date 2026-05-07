# Task: /etc/hosts — Write atomico + backup

## Obiettivo

Scrittura atomica di `/etc/hosts` (eseguita dall'helper privilegiato), con backup pre-scrittura e rollback su errore.

## Requisiti

- Backup in `/etc/hosts.hostflow.bak` prima di ogni write
- Write atomico: scrivi su file temp + rename
- Permessi/owner preservati (root:wheel, 644)
- Encoding UTF-8 newline `\n`
- Errore → throw + UI Alert utente

## Checklist

- [ ] Helper riceve `content: String` via XPC
- [ ] Step 1: copy `/etc/hosts` → `/etc/hosts.hostflow.bak`
- [ ] Step 2: write `content` su `/etc/hosts.hostflow.tmp`
- [ ] Step 3: `chmod 644` + `chown root:wheel` su tmp
- [ ] Step 4: `rename(tmp, "/etc/hosts")` (atomic)
- [ ] On any error: rollback (delete tmp, file originale intatto)
- [ ] Lato app: cattura errore e mostra `Alert` con messaggio + "Riprova"

## Note tecniche

- `FileManager.replaceItem(at:withItemAt:...)` è già atomico
- Verificare permessi post-write per evitare lock-out se hosts diventa non-leggibile
- Logging errori in `~/Library/Logs/HostFlow/helper.log`
