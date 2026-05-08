# Plan: /etc/hosts — Build blocco da profili attivi

**Date:** 2026-05-07
**Type:** feature

## Summary

Riformulare il `buildBlock` di `HostsFileManager`: aggiungere il warning "DO NOT EDIT MANUALLY" subito dopo lo start marker, intestare ogni profilo con `# --- <Name> ---`, ordinare i profili per `order`, e separare IP/hostname con spazio singolo (non tab) per massima compatibilità.

## Steps

1. [x] In `HostsFileManager.swift`: definire costanti private `warningLine1` / `warningLine2`
2. [x] Riscrivere `buildBlock(from profiles: [Profile]) -> String`:
   - sort profili per `order`
   - filter `isActive == true`
   - linea 1: `blockStart`
   - linee 2-3: warning
   - per ogni profilo: linea vuota + `# --- <profile.name> ---` + records (`<ip> <hostname>` se enabled, `# <ip> <hostname>` se disabled)
   - linea finale: `blockEnd`
3. [x] Sostituire `\t` con spazio singolo nei record
4. [x] Build verifica

## Out of scope

- Unit tests (no test target configurato) — il blocco sarà esercitato in task `21-hosts-write-atomic` quando il write privilegiato sarà reale
- Esposizione pubblica di `buildBlock` per preview/debugging — non c'è caller esterno per ora; resta `private`

## Open questions

- Nessuna
