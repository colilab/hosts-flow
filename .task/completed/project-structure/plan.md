# Plan: Struttura Progetto Xcode + Architettura Base MVVM

**Date:** 2026-05-06
**Type:** chore

## Summary

Creare il progetto Xcode per Host Flow con struttura cartelle MVVM, stub di tutti i modelli SwiftData, stores @Observable, views placeholder e helpers vuoti. L'obiettivo è un progetto compilabile con tutte e 3 le scene attive (finestra principale, MenuBarExtra, Settings) pronto per lo sviluppo delle feature successive. Nessuna logica reale verrà implementata in questo task.

## Steps

1. [x] Creare progetto Xcode "HostFlow" con target macOS 14.0+, SwiftUI, SwiftData — `HostFlow.xcodeproj`
2. [x] Creare struttura cartelle: App/, Models/, Stores/, Views/Sidebar/, Views/ProfileDetail/, Views/MenuBar/, Views/Settings/, Helpers/
3. [x] `App/HostFlowApp.swift` — entry point con WindowGroup, MenuBarExtra, Settings scene, ModelContainer condiviso
4. [x] `Models/Profile.swift` — @Model con id, name, isActive, order, records
5. [x] `Models/HostRecord.swift` — @Model con id, ip, hostname, isEnabled, relazione a Profile
6. [x] `Stores/ProfileStore.swift` — @Observable stub, lista profili
7. [x] `Stores/AppSettings.swift` — @Observable stub, appearance + launchAtLogin
8. [x] `Views/Sidebar/SidebarView.swift` — List + ProfileRowView con toggle
9. [x] `Views/ProfileDetail/ProfileDetailView.swift` — Table con toggle/edit/delete + AddRecordSheet + EditRecordSheet
10. [x] `Views/MenuBar/MenuBarView.swift` — lista profili con toggle + azioni
11. [x] `Views/Settings/SettingsView.swift` — Form con launch at login, appearance, versione
12. [x] `Helpers/HostsFileManager.swift` — read()/write() con marker block
13. [x] `ContentView.swift` — NavigationSplitView che usa SidebarView e ProfileDetailView

## Out of scope

- Logica reale di lettura/scrittura `/etc/hosts`
- UI funzionante (solo placeholders)
- Launch at login implementazione reale
- Gestione privilegi admin
- Qualsiasi feature della roadmap successiva al punto 1

## Open questions

- Nessuna
