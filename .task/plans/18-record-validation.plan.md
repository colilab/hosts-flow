# Plan: Record — Warning duplicati hostname

**Date:** 2026-05-08
**Type:** feature

## Summary

La validazione bloccante IP/hostname è coperta da `AddRecordSheet` + `EditRecordSheet` (entrambe usano `HostValidator.validateRecord`, bottone Salva/Aggiungi disabled su invalid, errore inline). Resta da implementare il warning visivo non-bloccante per hostname duplicati: icona `exclamationmark.triangle` + tooltip nella colonna Hostname della Table, valutato sia all'interno dello stesso profilo sia cross-profilo (tra profili attivi).

Definizione duplicato (case-insensitive lowercase):
- record di **questo** profilo (qualsiasi `isEnabled`) +
- record `isEnabled` di **altri** profili `isActive`
→ se un hostname appare ≥ 2 volte in questo set, è "duplicato".

## Steps

1. [ ] In `ProfileDetailView`: aggiungere `@Query private var allProfiles: [Profile]`
2. [ ] Computed `duplicatedHostnames: Set<String>`:
   - Conta hostname lowercased da: tutti i record di `profile` + record `isEnabled` di `allProfiles` con `isActive == true && id != profile.id`
   - Ritorna le chiavi con count > 1
3. [ ] In `TableColumn("Hostname")`: wrappare il `Text` esistente in un HStack(spacing: 4) che, se `duplicatedHostnames.contains(record.hostname.lowercased())`, mostra `Image(systemName: "exclamationmark.triangle.fill")` `.font(.caption) .foregroundStyle(.orange) .help("Hostname duplicato — l'ultimo record attivo prevarrà")`
4. [ ] Build verifica

## Out of scope

- Highlight visivo della riga intera — solo icona inline in cella Hostname
- Pannello / banner riassuntivo dei conflitti
- Risoluzione automatica dei duplicati
- Validazione bloccante — già fatta (vedi changelog)

## Open questions

- Nessuna
