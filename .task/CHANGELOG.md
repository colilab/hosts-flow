# Changelog

## [2026-05-07] — IP + hostname validation

**Type:** feature

### Changes
- Added `HostValidator` helper with static IPv4/IPv6 validation (via `inet_pton`) and RFC 1123 hostname regex (single-label allowed)
- Added `ValidationError: LocalizedError` enum (`emptyIP`, `invalidIP`, `emptyHostname`, `invalidHostname`) with Italian user-facing messages
- `validateRecord(ip:hostname:)` convenience that trims whitespace and returns the first failure
- Integrated validation in `AddRecordSheet`: "Aggiungi" disabled while invalid, inline red error message; saves trimmed values
- Integrated validation in `EditRecordSheet`: "Chiudi" disabled while invalid, inline red error message; trims on save
- Regenerated Xcode project to include new helper file

### Files modified
- `HostFlow/Helpers/HostValidator.swift` — new file: validators + error enum
- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — validation integration + trim on save
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — validation integration + trim on save
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Profile read-only flag

**Type:** chore

### Changes
- Added `isReadOnly: Bool` field to `Profile` model (default `false`, lightweight SwiftData migration)
- Added computed `isEditable` on `Profile` for use in views
- Added `canEdit(_:)` helper to `ProfileStore`
- `SidebarView.ProfileRowView` shows `lock.fill` SF Symbol next to the profile name when read-only
- Added tooltip "Profilo di sistema — duplica per modificare" on read-only rows
- Build verified: app compiles cleanly with the schema change

### Files modified
- `HostFlow/Models/Profile.swift` — added `isReadOnly` field, init parameter, `isEditable` computed
- `HostFlow/Stores/ProfileStore.swift` — added `canEdit(_:)` helper
- `HostFlow/Views/Sidebar/SidebarView.swift` — lock icon + tooltip on read-only rows

## [2026-05-06] — Xcode Project Scaffolding + MVVM Base Architecture

**Type:** chore

### Changes
- Created `project.yml` for XcodeGen with macOS 14.0+ target, sandbox entitlements, and `/etc/hosts` temporary exception
- Generated `HostFlow.xcodeproj` via `xcodegen generate`
- Defined SwiftData models: `Profile` (@Model, cascade delete) and `HostRecord` (@Model, inverse relationship)
- Implemented `@Observable ProfileStore` with profile CRUD and hosts write trigger
- Implemented `@Observable AppSettings` with appearance mode (persisted to UserDefaults) and launch-at-login via `SMAppService`
- Built `SidebarView` with `List`, per-profile toggle, add profile via Alert
- Built `ProfileDetailView` with SwiftUI `Table`, per-record toggle/edit/delete, search, `AddRecordSheet`, `EditRecordSheet`
- Built `MenuBarView` with per-profile toggles, "Open Host Flow", Settings link, Quit
- Built `SettingsView` with launch-at-login toggle, appearance picker, version info
- Implemented `HostsFileManager` with marker-based block read/write (`# --- Host Flow Start/End ---`)
- Created `ContentView` with `NavigationSplitView` wiring sidebar and detail

### Files modified
- `HostFlow/project.yml` — XcodeGen project definition
- `HostFlow/HostFlow.xcodeproj` — generated Xcode project
- `HostFlow/App/HostFlowApp.swift` — app entry point, 3 scenes, shared ModelContainer
- `HostFlow/App/ContentView.swift` — NavigationSplitView root
- `HostFlow/Models/Profile.swift` — SwiftData model
- `HostFlow/Models/HostRecord.swift` — SwiftData model
- `HostFlow/Stores/ProfileStore.swift` — observable store
- `HostFlow/Stores/AppSettings.swift` — observable settings
- `HostFlow/Views/Sidebar/SidebarView.swift` — sidebar + profile rows
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — record table
- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — add record modal
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — edit record modal
- `HostFlow/Views/MenuBar/MenuBarView.swift` — menu bar popover
- `HostFlow/Views/Settings/SettingsView.swift` — settings form
- `HostFlow/Helpers/HostsFileManager.swift` — hosts file read/write
- `HostFlow/Resources/Info.plist` — app metadata
- `HostFlow/Resources/HostFlow.entitlements` — sandbox + /etc/hosts permission
- `HostFlow/Resources/Assets.xcassets` — app icon placeholder
