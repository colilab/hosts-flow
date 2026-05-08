# Plan: Sidebar — Drag & drop reorder profili

**Date:** 2026-05-07
**Type:** feature

## Summary

Convertire il `List(profiles, selection:)` in `List(selection:) { ForEach(profiles) {...}.onMove }` per abilitare il drag & drop nativo macOS. Rispettare il vincolo: il profilo Default (readonly) resta sempre alla prima posizione — non può essere mosso e nessun altro profilo può prenderne il posto. Persistere via `ProfileStore.reorder` esistente, con trigger di `writeHosts` (l'ordine impatta i sub-header del blocco).

## Steps

1. [x] In `ProfileStore.reorder(_:context:)`: aggiungere `writeHosts(context: context)` in coda — l'ordine cambia gli header per-profilo nel blocco
2. [x] In `SidebarView`: convertire `List(profiles, selection:)` in `List(selection:) { ForEach(profiles, id: \.id) { ... } }`
3. [x] Su `ProfileRowView` dentro `ForEach`: aggiungere `.moveDisabled(profile.isReadOnly)` per bloccare il drag del Default
4. [x] `.onMove` sul `ForEach`: guard `destination > 0` (proibisce drop alla posizione 0 occupata dal Default), poi `var copy = Array(profiles); copy.move(fromOffsets: source, toOffset: destination); store.reorder(copy, context:)`
5. [x] Build verifica

## Out of scope

- Drag handle visivo esplicito — macOS usa whole-row drag, sufficiente
- Reorder dei `HostRecord` dentro un profilo
- Animazioni custom — quelle native bastano

## Open questions

- Nessuna
