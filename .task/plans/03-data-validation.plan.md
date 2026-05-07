# Plan: Validazione IP + Hostname

**Date:** 2026-05-07
**Type:** feature

## Summary

Creare un helper `HostValidator` con validazione IPv4/IPv6 (via `inet_pton`) e hostname (RFC 1123, single-label ammesso). Definire un enum `ValidationError: LocalizedError` con messaggi in italiano. Integrare la validazione in `AddRecordSheet` (disable "Aggiungi" + messaggio inline) e in `EditRecordSheet` (disable "Chiudi" + messaggio inline). Trim whitespace prima di ogni validazione.

## Steps

1. [x] Creare `HostFlow/Helpers/HostValidator.swift` con `isValidIPv4`, `isValidIPv6`, `isValidIP`, `isValidHostname` (tutte static)
2. [x] Aggiungere enum `ValidationError: LocalizedError` (casi `emptyIP`, `invalidIP`, `emptyHostname`, `invalidHostname`) con `errorDescription` in italiano
3. [x] In `AddRecordSheet`: computed `validationError: ValidationError?` su trim di `ip` + `hostname`; disable "Aggiungi" se errore; messaggio inline rosso sotto la Form; salvare con valori trimmati
4. [x] In `EditRecordSheet`: stessa logica — computed errore + disable "Chiudi" su invalid + messaggio inline; salvare con trim
5. [x] `xcodegen generate` per includere il nuovo file
6. [x] Build verifica

## Out of scope

- Warning per hostname duplicati cross-profilo → task `18-record-validation`
- Validazione avanzata IPv6 (zone IDs come `fe80::1%en0`) — `inet_pton` non li supporta nativamente; out of scope per ora
- Localizzazione (`.strings` files) — messaggi hardcoded in italiano per coerenza con il resto della UI

## Open questions

- Nessuna
