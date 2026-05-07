# Plan: /etc/hosts — Lettura + parsing blocco gestito

**Date:** 2026-05-07
**Type:** feature

## Summary

Sostituire l'attuale `HostsFileManager.read() -> String` con una versione strutturata che restituisce `HostsFileContent` (`preBlock` + `block?` + `postBlock`). Aggiungere enum `HostsFileError` (`notReadable`, `malformedBlock`, `encodingFailed`). Caso entrambi marker assenti → `block = nil` con tutto in `preBlock`. Caso 1 marker presente l'altro no → throw `.malformedBlock`. Tenere un `readRaw()` privato per uso interno di `write()`.

## Steps

1. [x] In `HostsFileManager.swift`: aggiungere struct `HostsFileContent { let preBlock: String; let block: String?; let postBlock: String }`
2. [x] Aggiungere enum `HostsFileError: LocalizedError` con casi `notReadable`, `malformedBlock`, `encodingFailed` + descrizioni italiane
3. [x] Sostituire `read() throws -> String` con `read() throws -> HostsFileContent`
4. [x] Implementare parser privato che splitta su `blockStart` / `blockEnd`, con tutti gli edge case
5. [x] Aggiungere private `readRaw() throws -> String` per uso interno di `write()`
6. [x] Aggiornare `write()` per chiamare `readRaw()` invece dell'ex `read()`
7. [x] Build verifica

## Out of scope

- Unit tests con mock content — il progetto non ha test target configurato; il parser sarà esercitato da `06-data-seed` in scenari reali. Aggiungere test target è un task separato (non a roadmap)
- Refactor di `write()` per usare `HostsFileContent` invece di `replaceBlock` — sarà rifatto in `21-hosts-write-atomic`

## Open questions

- Nessuna
