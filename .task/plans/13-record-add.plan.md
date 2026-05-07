# Plan: Record — Aggiungi record

**Date:** 2026-05-07
**Type:** feature

## Summary

Quasi tutto è già implementato in task precedenti (toolbar +, sheet, validation, append+writeHosts, readonly guard). Restano da aggiungere: placeholder espliciti nei TextField via `prompt:` (`"127.0.0.1"` per IP, `"example.local"` per hostname) e autofocus iniziale sul campo IP via `@FocusState`.

## Steps

1. [x] In `AddRecordSheet`: definire enum locale `Field { case ip, hostname }` + `@FocusState var focusedField: Field?`
2. [x] Aggiornare TextField IP: `TextField("Indirizzo IP", text: $ip, prompt: Text("127.0.0.1"))` + `.focused($focusedField, equals: .ip)`
3. [x] Aggiornare TextField hostname: `TextField("Hostname", text: $hostname, prompt: Text("example.local"))` + `.focused($focusedField, equals: .hostname)`
4. [x] `.onAppear { focusedField = .ip }` sul VStack root della sheet
5. [x] Build verifica

## Already done (no-op)

- Toolbar `+` con SF Symbol — task 01 scaffolding + readonly guard task 02
- `@State isAddingRecord` — task 01
- Sheet AddRecordSheet — task 01
- Validation live + disable bottone — task 03
- Append a `profile.records` + dismiss — task 01
- Trigger `writeHosts` — task 01

## Out of scope

- Sheet width = 380pt — già 360pt, accettabile
- Cambiare il titolo "Nuovo record"
- Refactor del Form

## Open questions

- Nessuna
