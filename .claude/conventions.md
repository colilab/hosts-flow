# Conventions

## SwiftUI

- Usa componenti nativi: `NavigationSplitView`, `List`, `Table`, `Toggle`, `TextField`, `MenuBarExtra`, `Settings` scene
- Nessun framework UI di terze parti
- `@Observable` macro (iOS 17+ / macOS 14+) preferito su `ObservableObject`
- `@Environment(\.modelContext)` per accesso SwiftData nelle view
- Editing inline record: `TextField` direttamente nella row, attivato da double-click o bottone edit

## Naming

- Views: `NomeFeatureView` (es. `SidebarView`, `ProfileDetailView`, `MenuBarView`)
- ViewModels / Stores: `NomeStore` o `NomeViewModel`
- Models: sostantivi semplici (`Profile`, `HostRecord`)
- Nessun prefisso tipo `VM`, `M`, `V`

## File Structure

```
HostFlow/
├── App/
│   └── HostFlowApp.swift
├── Models/
│   ├── Profile.swift
│   └── HostRecord.swift
├── Stores/
│   ├── ProfileStore.swift
│   └── AppSettings.swift
├── Views/
│   ├── Sidebar/
│   ├── ProfileDetail/
│   ├── MenuBar/
│   └── Settings/
└── Helpers/
    └── HostsFileManager.swift
```

## Codice

- Nessun commento ovvio — solo WHY non-ovvi
- Nessun `// MARK:` decorativo, solo se gruppano sezioni logiche distinte
- Nessuna gestione errori per scenari impossibili
- `guard` per early exit, non `if` annidati
- `private` su tutto ciò che non esce dal file

## Design (HIG)

- Colori: solo semantic colors (`Color.primary`, `.secondary`, `Color(nsColor: .controlAccentColor)`) — mai hardcoded
- Tipografia: `Font.body`, `.caption`, `.headline` — mai size fisse
- Spacing: multipli di 4pt o 8pt
- Nessuna ombra custom, nessun blur custom — solo effetti nativi (`.ultraThinMaterial` se serve)
- Toggle profilo nella sidebar: componente `Toggle` nativo con `.toggleStyle(.switch)` o checklist style
- Icone: SF Symbols esclusivamente

## Hosts File

- Blocco gestito delimitato da:
  ```
  # --- Host Flow Start ---
  ...
  # --- Host Flow End ---
  ```
- Mai toccare righe fuori dal blocco
- Record disabilitato → `# <ip> <hostname>`
- Profilo inattivo → nessuna riga (non commentata, rimossa)

## Errori & Permessi

- Errori scrittura `/etc/hosts` mostrati con `Alert` nativo
- Nessun crash silenzioso — propagare errori fino alla view
- Autorizzazione admin richiesta una volta, memorizzata in Keychain se possibile
