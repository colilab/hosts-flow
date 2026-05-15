# Plan: Spostamento record tra profili

**Date:** 2026-05-13
**Type:** feature

## Original prompt
> Crea un task all'interno di features per lo spostamento dei record da un profilo all'altro. I profili interessati non devono essere read only, ma modificabili.
>
> Sarà possibile spostare un record da un profilo A ad un profilo B:
> - con tasto destro "Sposta in" (menu a tendina con selezione profili)
> - con drag & drop del record verso un altro profilo nella sidebar a sx

## Summary

Aggiungere la possibilità di spostare uno o più `HostRecord` da un profilo A a un profilo B, sia da context menu nella tabella record (sottomenu "Sposta in" con la lista dei profili modificabili come destinazione), sia trascinando le righe selezionate sulle righe della sidebar. Solo profili non read-only sono coinvolti come sorgente o destinazione; i record duplicati nel profilo destinazione vengono spostati comunque (il warning arancione esistente segnalerà l'eventuale duplicato). Dopo lo spostamento viene richiesta una riscrittura di `/etc/hosts` tramite `store.scheduleWrite`.

## Requirements

- **Sorgente:** profilo correntemente selezionato (deve essere modificabile)
- **Destinazione:** un altro profilo modificabile (`!profile.isReadOnly`), diverso dalla sorgente
- **Multi-selezione:** entrambe le modalità operano sull'intero set di record selezionati
- **Duplicati:** spostamento sempre eseguito; il warning visivo esistente continua a indicare i duplicati
- **Drag & drop:** solo move (no copy con modifier)
- **Read-only:** esclusi sia da menu "Sposta in" che come target di drop nella sidebar
- **Post-spostamento:** `store.scheduleWrite(context:)` (la riscrittura effettiva avviene solo se sorgente o destinazione è attiva)
- **Selezione:** dopo lo spostamento `selectedRecordIDs` viene svuotata
- **Posizione nel destinazione:** record appesi in coda all'array `records` del profilo destinazione

## Steps

### 1. Modello dati / store
1. [x] Aggiungere helper `ProfileStore.moveRecords(_ records: [HostRecord], to destination: Profile, context: ModelContext)` — `HostFlow/Stores/ProfileStore.swift`
   - Guard: skip record già appartenenti a `destination`; skip se `destination.isReadOnly`
   - Per ogni record: `record.profile = destination` (la relationship inversa aggiorna le array)
   - `try? context.save()`
   - `scheduleWrite(context:)` alla fine

### 2. Transferable per drag & drop
2. [x] Creare `HostRecordTransfer: Codable, Transferable` (struct con `id: UUID`) — nuovo file `HostFlow/Models/HostRecordTransfer.swift` con `static var transferRepresentation` (CodableRepresentation, UTType custom es. `com.acolinucci.hostflow.hostrecord`)
3. [x] Registrare l'UTType custom in `HostFlow/Resources/Info.plist` (o `project.yml` se gestito da xcodegen) come exported type identifier

### 3. Context menu "Sposta in"
4. [x] In `ProfileDetailView.recordsList.contextMenu` aggiungere `Menu("Sposta in")` con elenco dei profili da `@Query` esclusi: il profilo corrente, i read-only — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
   - Disabilitato se `profile.isReadOnly` o se non esistono destinazioni valide
   - Ogni voce: `Button(target.name) { moveSelected(to: target, ids: items) }`
   - Helper privato `moveSelected(to:ids:)` che risolve gli ID in record e chiama `store.moveRecords(...)`, poi svuota `selectedRecordIDs`

### 4. Drag source nella tabella
5. [x] Sulla `Table` aggiungere `.draggable(...)` per riga (oppure `itemProvider` per riga) restituendo `HostRecordTransfer(id: record.id)` — disabilitato implicitamente quando `profile.isReadOnly` (verifica supporto Table su macOS target; in alternativa usare `.itemProvider` per riga)
   - Se la selezione è multipla e l'utente trascina una riga selezionata, devono partire tutti gli ID selezionati

### 5. Drop destination nella sidebar
6. [x] In `SidebarView` su ogni `ProfileRowView` aggiungere `.dropDestination(for: HostRecordTransfer.self)` con `isTargeted` per highlight nativo — `HostFlow/Views/Sidebar/SidebarView.swift`
   - `isEnabled: !profile.isReadOnly`
   - Handler: filtra gli ID rispetto al profilo corrente sorgente, risolve i record via `@Query`/context, chiama `store.moveRecords(records, to: profile, context:)`
   - Highlight target con `.background` su `isTargeted` (semantic color `.accentColor.opacity(0.2)` o `.selection`)

### 6. Gestione search filter
7. [x] Se la search è attiva, lo spostamento via context menu agisce solo sui record presenti nella selezione (che già appartengono a `filteredRecords`) — nessuna modifica necessaria, ma verificare il comportamento

### 7. Verifica build e UX
8. [x] Build da Xcode, verificare:
   - Context menu "Sposta in" mostra solo profili modificabili diversi dal corrente
   - Drag visibile dalla tabella, drop accettato solo su righe sidebar non read-only
   - Highlight visivo sulla riga sidebar durante il drag
   - Trigger di scrittura `/etc/hosts` quando sorgente o destinazione è attivo
   - Selezione svuotata post-spostamento

## Out of scope

- Copia di record (drag con Option) — esplicitamente non richiesta
- Spostamento via menu della sidebar (`Sposta tutti i record di questo profilo in...`)
- Annullamento via `Undo`/Cmd+Z
- Riordinamento dei record all'interno dello stesso profilo
- Spostamento da/verso profili read-only (esclusi per design)
- Conferma utente in caso di duplicato (scelta: spostamento sempre)

## Open questions

Nessuna.
