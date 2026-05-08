# Plan: Rimuovere xcuserdata dal tracking git

**Date:** 2026-05-08
**Type:** chore

## Original prompt
> vorrei rimuovere xcuserdata da git, perché nel gitignore è indicato non ci debbano essere ma in realtà vengono caricati. come mai?

## Summary
I file sotto `xcuserdata/` erano stati committati prima che le regole `.gitignore` venissero aggiunte. Le regole di gitignore non rimuovono file già tracciati: solo `git rm --cached` smette di tracciarli, dopodiché le regole esistenti impediranno futuri commit accidentali. Si rimuove il tracking senza riscrivere la storia.

## Steps
1. [ ] `git rm --cached` su `HostFlow/HostFlow.xcodeproj/project.xcworkspace/xcuserdata/luca.xcuserdatad/UserInterfaceState.xcuserstate`
2. [ ] `git rm --cached` su `HostFlow/HostFlow.xcodeproj/xcuserdata/luca.xcuserdatad/xcschemes/xcschememanagement.plist`
3. [ ] Verificare con `git ls-files | grep xcuserdata` che non risultino più tracciati
4. [ ] Verificare che `git status` mostri solo le rimozioni (i file restano sul disco locale)
5. [ ] Creare commit `chore: untrack xcuserdata files`

## Out of scope
- Riscrittura della storia git (i file resteranno nei commit passati)
- Modifiche al `.gitignore` (le regole esistenti sono già corrette)
- Push remoto (lasciato all'utente)

---

**Completed:** 2026-05-08

**Resolution:** Rimossi dal tracking git tre file `xcuserdata` (incluso uno di un altro utente, `acolinucci`, scoperto durante la verifica) tramite `git rm --cached` e committati in `03f2237`. I file restano sul disco locale; le regole gitignore esistenti coprono i futuri commit.
