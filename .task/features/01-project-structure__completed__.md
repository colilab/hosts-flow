# Task: Struttura Progetto Xcode + Architettura Base MVVM

## Obiettivo

Creare il progetto Xcode con struttura cartelle, dipendenze e scaffolding MVVM pronto per lo sviluppo delle feature successive.

## Requisiti

- macOS 14+ target (per `@Observable` macro)
- SwiftUI + SwiftData abilitati
- `MenuBarExtra` supportato (macOS 13+)
- Nessuna dipendenza di terze parti

## Checklist

### Progetto Xcode
- [x] Nuovo progetto Xcode — tipo "App" (non Document-based)
- [x] Bundle ID: `com.colilab.hostflow`
- [x] Target: macOS 14.0+
- [x] Abilitare "App Sandbox" con permessi necessari (lettura/scrittura file)
- [x] Aggiungere entitlement `com.apple.security.files.user-selected.read-write`

### Struttura cartelle
```
HostFlow/
├── App/
│   └── HostFlowApp.swift       ← App entry point, ModelContainer setup
├── Models/
│   ├── Profile.swift           ← @Model Profile
│   └── HostRecord.swift        ← @Model HostRecord
├── Stores/
│   ├── ProfileStore.swift      ← @Observable, CRUD + hosts write trigger
│   └── AppSettings.swift       ← @Observable, preferenze utente
├── Views/
│   ├── Sidebar/
│   │   └── SidebarView.swift
│   ├── ProfileDetail/
│   │   └── ProfileDetailView.swift
│   ├── MenuBar/
│   │   └── MenuBarView.swift
│   └── Settings/
│       └── SettingsView.swift
└── Helpers/
    └── HostsFileManager.swift  ← lettura/scrittura /etc/hosts
```

### App entry point (`HostFlowApp.swift`)
- [x] `WindowGroup` per finestra principale con `ContentView`
- [x] `MenuBarExtra` scene (icona SF Symbol: `"network"`)
- [x] `Settings` scene con `SettingsView`
- [x] `ModelContainer` condiviso iniettato nelle scene

### Modelli SwiftData
- [x] `Profile`: `id`, `name`, `isActive`, `order`, `records`
- [x] `HostRecord`: `id`, `ip`, `hostname`, `isEnabled`, relazione a `Profile`

### Stores @Observable
- [x] `ProfileStore` — CRUD profili + trigger writeHosts
- [x] `AppSettings` — `appearance` (system/light/dark), `launchAtLogin: Bool`

### Views
- [x] `ContentView` con `NavigationSplitView` sidebar/detail
- [x] `SidebarView` — List profili con toggle, add via Alert
- [x] `ProfileDetailView` — Table record con toggle/edit/delete + search
- [x] `MenuBarView` — lista profili con toggle + azioni
- [x] `SettingsView` — Form con launch at login, appearance, versione

### Helpers
- [x] `HostsFileManager` — read()/write() con marker block

---

**Completed:** 2026-05-06

**Resolution:** Progetto Xcode generato via XcodeGen con struttura MVVM completa, SwiftData models, @Observable stores, tutte le scene attive (WindowGroup + MenuBarExtra + Settings), e HostsFileManager con logica marker-based.
