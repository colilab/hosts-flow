# Changelog

## [2026-05-07] — Fill panes vertically in HSplitView

**Type:** bugfix

### Changes
- Selecting a profile with no records caused the whole window content (both panes) to collapse to its intrinsic height and center vertically — `HSplitView` was not being asked to fill its host
- Added `.frame(maxHeight: .infinity)` to `SidebarView`'s root VStack and to `ProfileDetailView`'s root VStack
- The empty-state `ContentUnavailableView` instances (in `ProfileDetailView` and the no-selection branch in `ContentView`) now claim `maxWidth/maxHeight: .infinity` so they fill the pane

### Files modified
- `HostFlow/Views/Sidebar/SidebarView.swift` — `.frame(maxHeight: .infinity)` on root
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — fills + ContentUnavailableView fill
- `HostFlow/App/ContentView.swift` — right pane Group fills

## [2026-05-07] — Sidebar — Inline profile rename

**Type:** feature

### Changes
- Double-clicking a sidebar profile name now switches it to a `TextField` with autofocus, blending into the row via `.textFieldStyle(.plain)`
- Enter commits, Esc reverts, click-outside (blur) commits as well
- Empty draft or unchanged name → silent revert
- Duplicate name (case-insensitive, excluding self) → silent revert (the brief red-flash warning was removed because it was nearly invisible on the selected-row blue background)
- Read-only profiles: double-click is a no-op (no editing mode)
- Editing state lives at `SidebarView` level (`editingProfileID: UUID?`) so only one row is editable at a time; rows receive `isEditing`/`existingNames`/`onBeginEdit`/`onEndEdit` props

### Files modified
- `HostFlow/Views/Sidebar/SidebarView.swift` — added inline rename in `ProfileRowView` + parent editing state

## [2026-05-07] — Fixed two-pane layout via HSplitView

**Type:** refactor

### Changes
- Replaced `NavigationSplitView` with `HSplitView` in `ContentView`
- Sidebar and detail are now both permanently visible — no collapse toggle, no show/hide animation
- Native draggable divider preserved between the two panes for manual resize
- Sidebar pane: `minWidth: 180, idealWidth: 220, maxWidth: 320`; detail pane: `minWidth: 400`

### Files modified
- `HostFlow/App/ContentView.swift` — NavigationSplitView → HSplitView with frame constraints

## [2026-05-07] — Sidebar — Add profile sheet

**Type:** feature

### Changes
- New `AddProfileSheet` with TextField + autofocus, live validation (empty + case-insensitive duplicate), inline red error, and Submit-on-Return
- "Crea" button disabled while invalid
- `ProfileStore.addProfile(name:context:)` now returns the created `Profile` (`@discardableResult`) so callers can auto-select it
- `SidebarView` replaces the previous `.alert` with the new sheet, then auto-selects the freshly created profile via `selectedProfile`
- Regenerated Xcode project to include the new sheet

### Files modified
- `HostFlow/Views/Sidebar/AddProfileSheet.swift` — new file: sheet with validation
- `HostFlow/Views/Sidebar/SidebarView.swift` — alert → sheet, auto-select on create
- `HostFlow/Stores/ProfileStore.swift` — `addProfile` returns the created profile
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Hosts block builder with warning and per-profile headers

**Type:** feature

### Changes
- `HostsFileManager.buildBlock` now emits a "DO NOT EDIT MANUALLY" warning (2 lines) immediately after the start marker
- Each active profile is preceded by a `# --- <Profile Name> ---` sub-header, separated by a blank line
- Profiles sorted by `order` before serialization for deterministic output
- Record formatting uses single space between IP and hostname (was tab) for broader tool compatibility
- Disabled records still serialized as `# <ip> <hostname>`; inactive profiles fully omitted

### Files modified
- `HostFlow/Helpers/HostsFileManager.swift` — `buildBlock` rewrite + warning constants

## [2026-05-07] — Enforce read-only on system profile UI

**Type:** bugfix

### Changes
- Extended task `02-data-readonly-flag`: read-only flag now actively disables UI controls instead of being a visual marker only
- `SidebarView.ProfileRowView` — profile `isActive` toggle disabled when `profile.isReadOnly`
- `MenuBarView.MenuBarProfileRow` — profile toggle disabled + lock icon shown next to the name
- `ProfileDetailView` toolbar — profile toggle and "Aggiungi record" button disabled when read-only (with help tooltip)
- `ProfileDetailView` records list — per-record `isEnabled` toggle, edit (pencil), and delete (trash) buttons all disabled when the parent profile is read-only
- Anticipates guards from upcoming tasks 13/15/16 — those tasks now find their checks already implemented

### Files modified
- `HostFlow/Views/Sidebar/SidebarView.swift` — `.disabled` on isActive toggle
- `HostFlow/Views/MenuBar/MenuBarView.swift` — `.disabled` on isActive toggle + lock badge
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `.disabled` on toolbar toggle, add button, record toggle, edit/delete buttons

## [2026-05-07] — Default profile seed from /etc/hosts

**Type:** feature

### Changes
- Added `HostsFileParser` helper with `ParsedHostRecord` struct, `parseSystemHosts()` (reads `/etc/hosts` excluding the Host Flow managed block), and `parse(_:)` for arbitrary content
- Parser handles commented records (`# 127.0.0.1 localhost` → disabled record), strips trailing inline comments, splits multi-hostname lines into separate records, validates IP and hostname via `HostValidator`
- Added `ProfileStore.seedIfNeeded(context:)` — idempotent, creates the "Default" profile (`isActive=true`, `isReadOnly=true`, `order=0`) populated from `/etc/hosts` on first launch
- Fail-safe: if `/etc/hosts` cannot be read, an empty Default profile is created and a warning is logged — no crash
- Wired `seedIfNeeded` into `ContentView.task` plus an `onChange(of: profiles.count)` that auto-selects the first profile after seeding completes
- Regenerated Xcode project to include the new parser file

### Files modified
- `HostFlow/Helpers/HostsFileParser.swift` — new file: parser + `ParsedHostRecord`
- `HostFlow/Stores/ProfileStore.swift` — `seedIfNeeded(context:)` helper
- `HostFlow/App/ContentView.swift` — seed on appear + reactive selection
- `HostFlow/HostFlow.xcodeproj` — regenerated

## [2026-05-07] — Structured /etc/hosts read

**Type:** feature

### Changes
- Added `HostsFileContent` struct with `preBlock`, `block` (optional), `postBlock` segments
- Added `HostsFileError: LocalizedError` enum (`notReadable`, `malformedBlock`, `encodingFailed`) with Italian messages
- Replaced `HostsFileManager.read() throws -> String` with `read() throws -> HostsFileContent` — parses the managed Host Flow block and returns segmented content
- Tolerant parser: both markers absent → `block = nil`, all content in `preBlock`; one marker present without the other → throws `.malformedBlock`
- Added private `readRaw()` helper used by the existing `write()` path — `write()` will be reworked under task 21

### Files modified
- `HostFlow/Helpers/HostsFileManager.swift` — structured read + content type + error enum

## [2026-05-07] — Profile ordering hardening

**Type:** chore

### Changes
- Fixed `ProfileStore.addProfile` — replaced fragile `count`-based order assignment (which produced duplicates after deletions) with `max(order) + 1`
- Added `ProfileStore.reorder(_:context:)` — accepts an already-ordered profile list and reassigns `order = index`, ready for the upcoming drag-reorder UI
- Verified `@Query(sort: \Profile.order)` already in place in `SidebarView` and `MenuBarView`

### Files modified
- `HostFlow/Stores/ProfileStore.swift` — `addProfile` fix + `reorder` helper

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
