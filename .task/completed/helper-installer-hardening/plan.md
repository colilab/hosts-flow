# Plan: Hardening dell'installer del privileged helper

**Date:** 2026-06-11
**Type:** bugfix

## Original prompt
> Hardening dell'installer del privileged helper (HelperInstaller.swift) per renderlo idempotente e robusto rispetto a stato launchd residuo. Contesto: un utente che installa via Homebrew ottiene "Bootstrap failed: 5: Input/output error" all'installazione e "Impossibile comunicare con un'applicazione di supporto" in scrittura, mentre altri utenti con identica macOS (Tahoe 26.5.1) e identico flusso brew non riproducono. Causa sospetta: brew uninstall non rimuove /Library/LaunchDaemons e /Library/PrivilegedHelperTools né fa bootout, lasciando un daemon "fantasma" registrato in launchd; il bootstrap successivo trova il label già caricato e fallisce con 5. Modifiche da considerare: bootout per label invece che per path, attesa che il servizio sparisca prima di sovrascrivere il binario, ownership/permessi forzati su file preesistenti, e refreshStatus() basato su launchctl print invece che sulla mera esistenza dei file.

## Summary
L'installazione dell'helper privilegiato fallisce con `Bootstrap failed: 5: Input/output error` quando launchd ha già un daemon "fantasma" registrato da una versione precedente (brew uninstall non pulisce `/Library/LaunchDaemons`, `/Library/PrivilegedHelperTools` né esegue `bootout`). Rendiamo lo script di install/uninstall idempotente: `bootout` per **label** (non per path), attesa bounded che il dominio si liberi prima di sovrascrivere il binario, ownership/permessi forzati anche su file preesistenti, e una verifica finale che `bootstrap` sia andato a buon fine. Aggiungiamo inoltre un controllo reale di registrazione via `launchctl print` usato nei flussi install/uninstall/Settings, lasciando `refreshStatus()` veloce (file-check) negli hot path di scrittura.

## Root cause
- `launchctl bootout system "<plist-path>"` fallisce silenziosamente (`|| true`) se il plist su disco non coincide con quello registrato → il servizio resta caricato.
- Il successivo `launchctl bootstrap system "<plist>"` trova il label **già presente** in launchd → `5: Input/output error`.
- Conseguenza: il `MachService` punta a un helper vecchio/morto → XPC `writeHosts` fallisce con "Impossibile comunicare con un'applicazione di supporto".
- Chi non riproduce ha semplicemente uno stato launchd pulito (nessun residuo da versioni precedenti).

## Steps
1. [x] Riscrivere lo script di **install** in `HelperInstaller.install()` — `HostFlow/Helpers/HelperInstaller.swift`:
   - `launchctl bootout system/<label>` (per label) invece che per path, tollerando il fallimento (servizio non presente).
   - Loop di **attesa bounded** (~3s, step 0.2s) finché `launchctl print system/<label>` smette di trovare il servizio, così il binario non è più in uso prima della `cp`.
   - `cp` + `chown root:wheel` + `chmod` forzati su binario (755) e plist (644), validi anche se i file preesistono.
   - `launchctl bootstrap system "<plist>"`.
   - **Verifica finale**: `launchctl print system/<label>` deve avere successo; in caso contrario `exit` con messaggio chiaro così che `scriptFailed` riporti l'errore reale.
2. [x] Riscrivere lo script di **uninstall** in `HelperInstaller.uninstall()` — usare `launchctl bootout system/<label>` (per label) coerentemente, poi `rm -f` dei due file.
3. [x] Estrarre il label e i path in costanti riusabili nello script (evitare interpolazioni ripetute, ridurre rischio di escaping).
4. [x] Aggiungere `verifyRegistered() -> Bool` in `HelperInstaller` che esegue `launchctl print system/<label>` e ritorna l'esito (subprocess, **non** nel hot path). — `HostFlow/Helpers/HelperInstaller.swift`
5. [x] Aggiornare `refreshStatus()`: mantenere il file-check veloce per gli hot path; quando i file esistono, confermare con `verifyRegistered()` **solo se** chiamato dai flussi non-hot. Realizzazione concreta: `refreshStatus()` resta file-based (usato da ProfileStore); aggiungere `refreshStatusVerified()` che combina file-check + `verifyRegistered()` e usarlo in `install()`/`uninstall()` (per impostare lo stato finale reale) e nel `.task` di Settings. — `HostFlow/Helpers/HelperInstaller.swift`, `HostFlow/Views/Settings/HelperSettingsSection.swift`
6. [x] Verificare che i call site in `ProfileStore.swift` (righe ~196, 330, 350, 368) restino sul `refreshStatus()` veloce — nessuna modifica funzionale lì, solo conferma di non introdurre subprocess sincroni nel path di scrittura.
7. [x] Build di verifica (`xcodebuild`/xcodegen) — deve compilare senza errori.

## Out of scope
- Notarizzazione o firma dell'helper (firma/macOS sono identiche tra chi riproduce e chi no → non è la causa).
- Modifiche al cask Homebrew o aggiunta di un hook di uninstall in brew (gestito in un eventuale task separato sul tap repo).
- Modifiche a `CallerVerification` / manifest hashing.
- Verifica funzionale reale del fix sulla macchina che riproduce: delegata all'utente (vedi nota verifica).
- Nuove stringhe localizzate di errore, salvo che la verifica finale richieda un messaggio dedicato; in tal caso si riusa `error.installer.script_failed` esistente.

## Verifica
Build locale + code review. La conferma funzionale (assenza di errore 5 in presenza di daemon fantasma) la esegue l'utente che riproduce il bug, poiché lo stato launchd residuo non è presente sulla macchina di sviluppo.

## Open questions
- Nessuna.

---

**Completed:** 2026-06-11

**Resolution:** Reso idempotente l'installer dell'helper: bootout per label, attesa bounded prima della copia del binario, permessi forzati, verifica post-bootstrap con `launchctl print`; aggiunto `refreshStatusVerified()`/`isRegistered()` per lo stato reale fuori dagli hot path, mantenendo `refreshStatus()` veloce in ProfileStore. Build verificata (BUILD SUCCEEDED); conferma funzionale delegata all'utente che riproduce il bug.
