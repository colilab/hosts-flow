# Plan: Seed iniziale profilo "Default" da /etc/hosts

**Date:** 2026-05-07
**Type:** feature

## Summary

Al primo avvio, popolare un profilo "Default" (`isActive=true`, `isReadOnly=true`, `order=0`) leggendo lo stato reale di `/etc/hosts` ed escludendo il blocco Host Flow eventualmente presente. Creare un parser riusabile `HostsFileParser` (sarà condiviso con il task 35-import-hosts-format), e cablare `seedIfNeeded` in `ContentView.task`. Idempotente: re-run no-op se ci sono già profili.

## Steps

1. [x] Creare `HostFlow/Helpers/HostsFileParser.swift` con:
   - struct `ParsedHostRecord { ip; hostname; isEnabled }`
   - `static func parseSystemHosts() throws -> [ParsedHostRecord]` che usa `HostsFileManager.read()` e parsa solo `preBlock + postBlock`
   - `static func parse(_ content: String) -> [ParsedHostRecord]` che applica le regole: skip empty/pure-comment, riconoscimento commented records, multi-hostname split, validazione IP/hostname tramite `HostValidator`
2. [x] In `ProfileStore.swift`: aggiungere `func seedIfNeeded(context: ModelContext)` — count > 0 ⇒ return early; crea Default `isActive=true, isReadOnly=true, order=0`; chiama `parseSystemHosts()` in `try?` (failure ⇒ Default vuoto, no crash); inserisce un `HostRecord` per ogni `ParsedHostRecord` con `isEnabled` corretto; salva contesto
3. [x] In `ContentView.swift`: aggiungere `@Environment(ProfileStore.self)` + `@Environment(\.modelContext)`; `.task { store.seedIfNeeded(context:) }`; `.onChange(of: profiles.count)` per auto-selezionare il primo profilo dopo il seed (l'`.onAppear` esistente copre il caso store già popolato)
4. [x] Build verificato. Test manuale visivo (run + inspect sidebar) demandato all'utente

## Out of scope

- Watcher di edit esterni a `/etc/hosts` → task `23-hosts-watch-external`
- Guard concreti contro modifica del Default → task `09/10/11/13/14/15/16` (già readonly come marker UI)
- Validation cross-profilo → task `18-record-validation`
- Test manuale del primo `writeHosts` reale (richiede privileged helper) → task `19-22`

## Open questions

- Nessuna
