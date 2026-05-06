# Project Brief: Host Flow

## 1. Product Vision

Host Flow è un'app macOS nativa per sviluppatori e sysadmin che vogliono gestire host virtuali in modo semplice e veloce. Ispirata a iHosts, permette di creare profili di host attivabili/disattivabili singolarmente o in combinazione. Si integra nativamente con macOS seguendo le Human Interface Guidelines Apple e sfrutta i componenti SwiftUI standard.

## 2. Riferimento

- **Ispirazione principale:** iHosts (App Store macOS)
- **Platform target:** macOS (ARM + Intel), SwiftUI nativo
- **Design system:** Apple HIG, componenti SwiftUI nativi

## 3. Core Features

### Profili
- Creazione, rinomina, eliminazione di profili (es. "Default", "Sviluppo", "Produzione", "Testing")
- Ogni profilo ha un toggle per attivarlo/disattivarlo
- Più profili possono essere attivi simultaneamente
- I profili attivi vengono uniti e scritti su `/etc/hosts`

### Host Records
- Ogni profilo contiene una lista di record host (IP + hostname + tipo opzionale)
- CRUD completo: aggiunta, modifica inline, eliminazione
- Ogni singolo record ha un toggle attiva/disattiva (record disattivato = commentato in `/etc/hosts`)
- Ricerca/filtro nella lista record

### Menu Bar
- Icona nella top bar macOS (menu bar extra)
- Dal menu bar: lista profili con toggle rapido attiva/disattiva
- Accesso rapido a Settings dal menu bar

### Settings
- Launch at login
- Richiesta privilegi di scrittura su `/etc/hosts` (con autorizzazione amministratore)
- Gestione appearance (System / Light / Dark)
- Info versione app

## 4. UI Architecture

### Finestra principale
- **Layout:** Split view con sidebar fissa a sinistra + content area a destra
- **Sidebar:**
  - Lista profili con toggle attiva/disattiva inline per ciascuno
  - Bottone "+" per aggiungere profilo
  - Click su profilo = selezione (highlight nativo macOS)
  - In fondo: bottone Settings (icona ingranaggio)
- **Content area (profilo selezionato):**
  - Header con nome profilo e stato attivo/inattivo
  - Tabella/lista record host con colonne: Toggle | IP | Hostname | Azioni (edit/delete)
  - Edit inline (row editing nativo SwiftUI/AppKit style)
  - Bottone "Aggiungi record" in fondo o nella toolbar

### Menu Bar
- `MenuBarExtra` SwiftUI (macOS 13+)
- Popover o menu con lista profili e toggle
- Voce "Apri Host Flow" per portare in primo piano la finestra principale
- Voce "Impostazioni..."

## 5. Technical Specifications

- **Framework:** SwiftUI (target macOS 13+ per `MenuBarExtra`)
- **Persistenza:** SwiftData o file JSON locale in Application Support
- **Scrittura `/etc/hosts`:** XPC service con privilegi elevati, oppure `AuthorizationExecuteWithPrivileges` (legacy)
- **Architettura:** MVVM, ObservableObject / @Observable macro
- **Componenti nativi da preferire:** `List`, `Table`, `NavigationSplitView`, `Toggle`, `TextField` inline, `MenuBarExtra`, `Settings` scene

## 6. Roadmap

- [ ] Struttura progetto Xcode + architettura base MVVM
- [ ] Modello dati: Profile + HostRecord (SwiftData)
- [ ] Sidebar profili con toggle e CRUD
- [ ] Content view record con edit inline e toggle per record
- [ ] Scrittura/lettura `/etc/hosts` (gestione privilegi)
- [ ] Menu Bar Extra con toggle profili
- [ ] Settings scene (launch at login, appearance)
- [ ] Dark mode pieno supporto
- [ ] Batch import/export (`/etc/hosts` format)
