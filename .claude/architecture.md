# Architecture

## Pattern: MVVM

- **Model:** SwiftData entities (`Profile`, `HostRecord`)
- **ViewModel:** `@Observable` classes per feature, injected via environment
- **View:** SwiftUI views, no business logic

## App Structure

```
HostFlowApp (App)
├── MainScene (WindowGroup)
│   └── ContentView
│       └── NavigationSplitView
│           ├── SidebarView          ← profile list + settings button
│           └── ProfileDetailView    ← host records for selected profile
└── MenuBarScene (MenuBarExtra)
│   └── MenuBarView                  ← quick profile toggles
└── SettingsScene (Settings)
    └── SettingsView
```

## Data Model

```swift
@Model class Profile {
    var id: UUID
    var name: String
    var isActive: Bool
    var order: Int
    var records: [HostRecord]
}

@Model class HostRecord {
    var id: UUID
    var ip: String
    var hostname: String
    var isEnabled: Bool
    var profile: Profile
}
```

Persistenza: **SwiftData** con `ModelContainer` condiviso tra tutte le scene (incluso MenuBarExtra).

## Hosts File Writer

Componente isolato `HostsFileManager`:
- Legge stato corrente di `/etc/hosts`
- Calcola blocco gestito da Host Flow (tra marker `# --- Host Flow Start ---` / `# --- Host Flow End ---`)
- Riscrive solo il blocco gestito, preservando il resto
- Record disabilitati scritti come commenti (`# 127.0.0.1 example.local`)
- Profili inattivi esclusi completamente
- Privilegi: richiesta autorizzazione admin via `SMJobBless` XPC helper o `AuthorizationExecuteWithPrivileges`

## State Management

- `ProfileStore: @Observable` — lista profili, operazioni CRUD, trigger scrittura hosts
- `AppSettings: @Observable` — preferenze (appearance, launch at login)
- Entrambi iniettati con `.environment()` a livello root

## Scene & Permissions

- `MenuBarExtra` (macOS 13+) usa stesso `ModelContainer` della finestra principale
- Launch at login via `SMAppService.mainApp` (macOS 13+)
- Scrittura `/etc/hosts` richiede privilegi → mostrare dialog autorizzazione al primo avvio e quando necessario
