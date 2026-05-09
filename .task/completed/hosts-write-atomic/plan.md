# Plan: /etc/hosts — Write atomico + backup

**Date:** 2026-05-09
**Type:** feature

## Original prompt
> # Task: /etc/hosts — Write atomico + backup
>
> ## Obiettivo
>
> Scrittura atomica di `/etc/hosts` (eseguita dall'helper privilegiato), con backup pre-scrittura e rollback su errore.
>
> ## Requisiti
>
> - Backup in `/etc/hosts.hostflow.bak` prima di ogni write
> - Write atomico: scrivi su file temp + rename
> - Permessi/owner preservati (root:wheel, 644)
> - Encoding UTF-8 newline `\n`
> - Errore → throw + UI Alert utente
>
> ## Checklist
>
> - [ ] Helper riceve `content: String` via XPC
> - [ ] Step 1: copy `/etc/hosts` → `/etc/hosts.hostflow.bak`
> - [ ] Step 2: write `content` su `/etc/hosts.hostflow.tmp`
> - [ ] Step 3: `chmod 644` + `chown root:wheel` su tmp
> - [ ] Step 4: `rename(tmp, "/etc/hosts")` (atomic)
> - [ ] On any error: rollback (delete tmp, file originale intatto)
> - [ ] Lato app: cattura errore e mostra `Alert` con messaggio + "Riprova"
>
> ## Note tecniche
>
> - `FileManager.replaceItem(at:withItemAt:...)` è già atomico
> - Verificare permessi post-write per evitare lock-out se hosts diventa non-leggibile
> - Logging errori in `~/Library/Logs/HostFlow/helper.log`

## Summary

La pipeline backup → write tmp → chmod/chown → atomic rename era già in `HelperService.performWrite` (introdotta dal task `hosts-write-helper`). Questo plan chiude i tre gap rimasti rispetto alla spec: rollback effettivo del tmp se uno step intermedio fallisce, file log errori del helper, e Alert "Riprova" lato app collegato a `ProfileStore.lastWriteError` (che era popolato ma mai mostrato).

## Steps

1. [x] `HelperService.performWrite`: avvolgere `data.write(...)` + `setAttributes` + `replaceItemAt` in `do/catch` che rimuove il `tmp` se uno qualsiasi degli step fallisce. Il `removeItem(at: tmpURL)` pre-write è restato com'era (idempotenza in caso di tmp residuo da un crash precedente)
2. [x] `HelperService`: aggiungere static `appendErrorLog(_:)` che append su `/Library/Logs/HostFlow/helper.log` con timestamp ISO8601, crea la directory on-demand e fa `chmod 644` al primo write. Chiamato dal `catch` di `writeHosts` accanto a `os_log`
3. [x] `ProfileStore.lastWriteError`: rimosso `private(set)` per consentire all'alert di azzerare il valore senza un metodo dedicato
4. [x] `ContentView`: aggiunto `.alert("Errore di scrittura /etc/hosts", ...)` con `presenting: store.lastWriteError`, bottone "Riprova" (rilancia `store.writeHosts(context:)`) e bottone "Annulla" (role `.cancel`)
5. [x] Aggiornato `.task/CHANGELOG.md`

## Out of scope

- Unit test del rollback (no test target configurato)
- Notifica a finestra chiusa (errore via MenuBar) — discusso in fase di grilling, scelta esplicita: alert solo su `ContentView`
- Apertura del log file da UI ("Apri log" come azione dell'alert) — discusso, non scelto

## Open questions

- **Path del log**: la spec dice `~/Library/Logs/HostFlow/helper.log` ma il helper gira come root, quindi `~` risolverebbe a `/var/root/Library/Logs/...` (illeggibile dall'utente senza sudo). Implementato come `/Library/Logs/HostFlow/helper.log` (convenzione macOS per daemon di sistema, world-readable). Da confermare con l'utente; se preferisce il path letterale, va modificato `HelperService.logFileURL`.

---

**Completed:** 2026-05-09

**Resolution:** Pipeline write atomica chiusa lato spec: rollback del tmp ora copre anche fallimenti mid-pipeline (`setAttributes` o `replaceItemAt`), errori scritti su `/Library/Logs/HostFlow/helper.log` (deviazione documentata da `~/Library/Logs/...`) oltre che su `os_log`, e l'utente vede un alert nativo con "Riprova"/"Annulla" quando la write XPC fallisce. Modifiche in `HostFlow/Helper/HelperService.swift`, `HostFlow/Stores/ProfileStore.swift`, `HostFlow/App/ContentView.swift`.
