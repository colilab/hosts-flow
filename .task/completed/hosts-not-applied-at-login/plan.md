# Plan: Apply managed hosts block on app launch

**Date:** 2026-05-18
**Type:** bugfix

## Original prompt
> ho trovato un possibile bug da analizzare. venerdì ho installato la versione release di Host Flow e poi sabato ho spento il mio mac mini. oggi (lunedì) ho acceso il mac mini e correttamente Host Flow si è avviato (start at login è true) con i profili attivi, tuttavia non sono stati realmente applicati al file /etc/hosts

## Summary
All'avvio l'app esegue `seedIfNeeded` e avvia il watcher su `/etc/hosts`, ma non riconcilia mai il blocco gestito con lo stato dei profili nel DB. Dopo un reboot del Mac, se il blocco gestito è assente, stale o è stato rigenerato da un'altra fonte, i profili "attivi" nel DB non producono alcuna riga in `/etc/hosts` finché l'utente non tocca un toggle. Fix: forzare una scrittura del blocco gestito all'avvio, in silenzio se l'helper non è installato.

## Decisioni concordate
- **Trigger:** sempre riscrivere il blocco gestito all'avvio (no diff check).
- **Helper assente:** scrittura silenziosa, niente onboarding sheet automatico al launch (l'utente lo vedrà comunque la prossima volta che modifica qualcosa).
- **Hook:** in `ContentView.task`, dopo `seedIfNeeded` e prima/dopo `watcher.start`. Una sola volta per ciclo di vita dell'app (il `.task` su `ContentView` parte una volta al primo render della finestra principale).

## Steps
1. [x] Aggiungere in [ProfileStore.swift](HostFlow/Stores/ProfileStore.swift) un metodo `applyOnLaunch(context:)` che invoca la logica di `writeHostsImmediate` ma **senza** impostare `helperMissing = true` quando l'helper non è installato (semplice early-return silenzioso). Riusa lo stesso `HostsFileManager.shared.write(profiles:)` e aggiorna `lastWriteAt` / `lastWriteError`.
2. [x] In [ContentView.swift:64-67](HostFlow/App/ContentView.swift#L64-L67) chiamare `store.applyOnLaunch(context: context)` subito dopo `store.seedIfNeeded(context: context)` e prima di `watcher.start(...)`, così l'eventuale modifica del file fatta dalla nostra scrittura non triggera un falso sync del watcher (la logica esistente in `runSync` ha già `mtimeToleranceSeconds`, ma scrivere prima dello `start` è più robusto).
3. [x] Verifica manuale (descritta sotto, l'utente la farà a mano dopo build).

## Out of scope
- Diff-check fra blocco gestito attuale e DB (l'utente ha scelto "sempre riscrivere").
- Mostrare onboarding helper al launch.
- Cambiamenti al watcher o a `syncDefaultFromFile`.
- Notifica utente di scrittura riuscita all'avvio.

## Verifica manuale (post-fix)
1. Avere almeno un profilo attivo con qualche record.
2. Rimuovere manualmente il blocco gestito da `/etc/hosts` (oppure riavviare il Mac).
3. Avviare l'app → `/etc/hosts` deve contenere nuovamente il blocco con i record dei profili attivi.
4. Disinstallare l'helper → riavviare l'app → nessun crash, nessun sheet automatico al launch, scrittura saltata in silenzio.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-18

**Resolution:** Added `ProfileStore.applyOnLaunch(context:)` (silent if helper missing) and invoked it from `ContentView.task` before `watcher.start`, so active profiles are always re-applied to `/etc/hosts` at launch — including after a reboot.
