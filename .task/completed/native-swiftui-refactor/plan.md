# Task: Refactor — Migrazione a componenti SwiftUI nativi

## Obiettivo

Allineare 4 elementi UI alle API native SwiftUI e a `.claude/architecture.md` / `.claude/conventions.md`. Nessun cambio funzionale: stesso comportamento utente, ma componenti standard macOS (toggle sidebar nativo, search field in toolbar, footer sidebar con `safeAreaInset`). Out of scope: icona menu bar custom (resta asset `MenuBarIcon`).

## Requisiti

- `HSplitView` → `NavigationSplitView` con stile `.balanced`. Vincoli larghezza: sidebar min 180 / ideal 220 / max 320, detail min 400.
- Title bar standard: rimuovere `.windowStyle(.hiddenTitleBar)` dalla scena principale per abilitare toggle nativo sidebar e ospitare `.searchable` in toolbar.
- Search bar custom in `ProfileDetailView` → modificatore nativo `.searchable(text:)` con placement automatico. State `searchText` resta locale alla detail view; logica `filteredRecords` e `ContentUnavailableView.search` invariate.
- Footer custom della `SidebarView` (HStack con `frame(height: 36)` dopo un `Divider`) → `.safeAreaInset(edge: .bottom)` sulla `List`. Mantenere elementi: bottone "Nuovo profilo", `ProgressView` durante scrittura, `SettingsLink`.
- `RecordDropModifier` (ViewModifier custom) → inline nella `ProfileRowView` con applicazione condizionale di `.dropDestination` (no drop target registrato sui profili read-only).

## Checklist

- [ ] `HostFlowApp.swift`: rimosso `.windowStyle(.hiddenTitleBar)` dalla scena `Window("Host Flow", id: "main")`
- [ ] `ContentView.swift`: `HSplitView` sostituito da `NavigationSplitView { Sidebar } detail: { Detail }`
- [ ] `ContentView.swift`: `.navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)` su sidebar, `.navigationSplitViewColumnWidth(min: 400, ideal: 600)` su detail
- [ ] `ContentView.swift`: `.navigationSplitViewStyle(.balanced)` applicato
- [ ] `ContentView.swift`: rimosso `.ignoresSafeArea(.all, edges: .top)` (non più necessario con title bar standard)
- [ ] `SidebarView.swift`: rimosso `VStack(spacing: 0)` esterno + HStack footer con `frame(height: 36)`
- [ ] `SidebarView.swift`: `.safeAreaInset(edge: .bottom)` sulla `List` con HStack (Nuovo profilo | ProgressView | SettingsLink)
- [ ] `SidebarView.swift`: eliminato `RecordDropModifier`, drop applicato inline in `ProfileRowView` con `if !profile.isReadOnly { row.dropDestination(...) }`
- [ ] `ProfileDetailView.swift`: rimossa private var `searchBar` e relativa occorrenza nel body
- [ ] `ProfileDetailView.swift`: `.searchable(text: $searchText, prompt: "Cerca IP o hostname...")` applicato (placement automatico)
- [ ] Build di verifica (compilazione)
- [ ] Test manuale: collapse sidebar via toggle nativo, vincoli width, search filtra IP/hostname, footer sidebar (bottone/progress/settings), drag-and-drop record verso profili non read-only, drop bloccato su profili read-only

## Note tecniche

- Stile NavigationSplitView confermato `.balanced` (default macOS, sidebar+detail coesistono).
- `.searchable` su `ProfileDetailView` root: il campo appare nella toolbar finestra (abilitata dal punto title bar standard) e si aggiorna naturalmente al cambio di profilo selezionato.
- `.safeAreaInset(edge: .bottom)` su `List` dentro una colonna `NavigationSplitView`: divider/background nativi senza altezza fissa, padding orizzontale 12 / verticale 8.
- Drop inline: applicare `.dropDestination(for: HostRecordTransfer.self)` solo nel ramo `!profile.isReadOnly`. Sui profili read-only la row non registra drop target (preferito a un onDrop che fa early-return: zero highlight, zero hit-test).
- `MenuBarIcon` resta invariato (punto fuori scope).

---

**Completed:** 2026-05-15

**Resolution:** Refactor applicato come da plan. `xcodebuild ... build` → BUILD SUCCEEDED. Validazione UX manuale da fare nell'app (sidebar toggle nativo, `.searchable` in toolbar, footer sidebar, drag-and-drop record).
