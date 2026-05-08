# Changelog

## [2026-05-08] — Untrack xcuserdata files

**Type:** chore

### Changes
- Removed `xcuserdata` files from git tracking; they had been committed before the `.gitignore` rules were added, so the existing ignore patterns had no effect on already-tracked paths
- Files remain on disk locally; future changes will be ignored by the existing `*.xcodeproj/xcuserdata/` and `*.xcworkspace/xcuserdata/` rules

### Files modified
- `HostFlow/HostFlow.xcodeproj/project.xcworkspace/xcuserdata/luca.xcuserdatad/UserInterfaceState.xcuserstate` — untracked
- `HostFlow/HostFlow.xcodeproj/xcuserdata/luca.xcuserdatad/xcschemes/xcschememanagement.plist` — untracked
- `HostFlow/HostFlow.xcodeproj/xcuserdata/acolinucci.xcuserdatad/xcschemes/xcschememanagement.plist` — untracked

## [2026-05-08] — Record — Duplicate (ip, hostname) pair warning

**Type:** feature

### Changes
- Added `@Query` for all profiles to `ProfileDetailView` so the detail can reason about cross-profile state
- Added `RecordPair` `Hashable` (lowercased ip + hostname) and computed `duplicatedPairs: Set<RecordPair>` — counts the (ip, hostname) pair across this profile's records (any state) plus enabled records of other active profiles; entries with count > 1 are flagged
- Pair-based detection avoids false positives like the standard loopback `::1 localhost` + `127.0.0.1 localhost` — different IPs for the same hostname are NOT considered duplicates
- Hostname column in the records Table now wraps the `Text` in an `HStack` and shows an orange `exclamationmark.triangle.fill` SF Symbol with `.help` tooltip "Record duplicato — stessa coppia IP/hostname presente più volte" whenever the row's pair is in the duplicate set
- Validation (blocking) on IP / hostname during add and edit was already covered by tasks 03 + (revised) modal Edit; this task only adds the non-blocking duplicate awareness

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `@Query allProfiles`, `RecordPair` + `duplicatedPairs` computed, warning icon in Hostname column

## [2026-05-08] — Record edit — Modal-only with explicit Save / Cancel

**Type:** refactor

### Changes
- Rolled back the double-click inline edit on IP / Hostname Table cells (task 14): on validation failure the cell stayed open with stale draft text, on click-out the change appeared "saved" while the model was actually unchanged — confusing UX
- Removed `CellAddress`, `editingCell`, `draftValue`, `focusedCell`, `editableCell(...)`, `startEdit/commitEdit/cancelEdit`
- IP / Hostname columns are now plain `Text` views again (with `.opacity(0.5)` for disabled records preserved from task 15)
- Context menu in records Table extended with **"Modifica"** entry (visible only when a single record is selected, disabled when profile is read-only) — opens the existing `EditRecordSheet` modal
- `EditRecordSheet` refactored to use a **draft buffer** (`@State ip`, `@State hostname` initialised from the record) so edits no longer mutate the SwiftData object during typing
- Modal now exposes explicit **"Annulla"** (cancel — discards changes) and **"Salva"** (.borderedProminent, disabled while invalid) buttons instead of the previous single "Chiudi"
- Inline error message + Italian labels + `prompt:` placeholders + `@FocusState` autofocus on IP — consistent with `AddRecordSheet`

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — removed inline-edit infrastructure, plain Text columns, "Modifica" in context menu
- `HostFlow/Views/ProfileDetail/EditRecordSheet.swift` — draft buffer + Annulla / Salva buttons + autofocus

## [2026-05-07] — Record — Search empty state

**Type:** feature

### Changes
- `ProfileDetailView` body now distinguishes three cases: profile with no records, search active with no matches, normal records list
- For the search-no-match case, uses native `ContentUnavailableView.search(text:)` which renders the standard macOS "No Results" view with the current query
- Search bar / filtering / clear button were already in place from the earlier `HSplitView` refactor — this task added only the empty state branch

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — three-way conditional with `ContentUnavailableView.search` branch

## [2026-05-07] — Record delete with multi-select

**Type:** feature

### Changes

- Replaced individual delete buttons with selection-based deletion following macOS conventions
- Added multi-select support (Cmd+click) for batch record deletion
- Added context menu with "Elimina" option on selected records
- Added Delete key support to remove selected records
- Removed the actions column (pencil and trash buttons) - edit is now via double-click, delete via context menu or Delete key
- Delete operations respect read-only profile guard and trigger hosts file write

### Files modified

- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — added multi-select state, context menu, Delete key handler, removed actions column

## [2026-05-07] — Record toggle visual feedback

**Type:** feature

### Changes

- Enhanced visual feedback for disabled host records by adding reduced opacity (0.5) in addition to the existing secondary color
- Disabled records now display with both secondary foreground color and 50% opacity for clearer visual distinction following macOS conventions
- Visual feedback applies to both IP and hostname columns in the records table

### Files modified

- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — added `.opacity(record.isEnabled ? 1.0 : 0.5)` modifier to text cells

## [2026-05-07] — Record — Inline edit IP / hostname

**Type:** feature

### Changes
- Double-clicking an IP or Hostname cell in the records `Table` swaps the `Text` for an inline `TextField` driven by `@FocusState`-managed focus
- Added `CellAddress` `Hashable` struct (recordID + field) to track which cell is being edited
- Return on the IP cell commits the value and advances focus to the Hostname cell of the same row; Return on Hostname commits and exits
- Tab key handled via `.onKeyPress(.tab)` for the same advance/close behaviour
- Esc cancels (`.onExitCommand`) — value reverts
- Validation per field via `HostValidator.isValidIP` / `isValidHostname` on commit; failure shows a red `RoundedRectangle` overlay border on the editing cell, no save, edit stays open until the user fixes or cancels
- Read-only profiles: double-click is a no-op
- Successful commit triggers `writeHosts` so `/etc/hosts` reflects the change immediately for active profiles
- The modal `EditRecordSheet` (pencil button) is preserved alongside as an alternative entry point

### Files modified
- `HostFlow/Views/ProfileDetail/ProfileDetailView.swift` — `CellAddress` struct, editing state + `@FocusState`, `editableCell(...)` helper, `startEdit/commitEdit/cancelEdit`, IP/Hostname columns updated to use the editable cell

## [2026-05-07] — Record — Add record polish

**Type:** feature

### Changes

- `AddRecordSheet`: switched the IP/hostname field labels to Italian (`"Indirizzo IP"`, `"Hostname"`) and added inline placeholders via `prompt:` (`"127.0.0.1"` and `"example.local"`)
- Added `@FocusState`-driven autofocus on the IP field when the sheet opens
- Most other checklist items for this task were already in place from earlier work (toolbar `+`, sheet wiring, validation + disable, append + writeHosts, readonly guard) — this task just polished the input UX

### Files modified

- `HostFlow/Views/ProfileDetail/AddRecordSheet.swift` — `Field` focus enum, prompts, autofocus

## [2026-05-07] — Sidebar row — Tight name truncation

**Type:** bugfix

### Changes

- Profile name in sidebar rows was truncating with ellipsis well before reaching the toggle, leaving a noticeable empty gap
- Root cause: `Toggle` with an `EmptyView()` label still reserved horizontal space for the invisible label slot; combined with a missing outer width constraint, the row never offered the full available width to the name `Text`
- Added `.labelsHidden()` on the profile `Toggle` so it occupies only the actual switch width
- Replaced the inner-HStack-with-frame trick with a flat HStack: `Text/TextField` → `Lock?` (adjacent to the name) → `Spacer(minLength: 0)` → `Toggle`
- Outer HStack now `.frame(maxWidth: .infinity)` so the row claims full sidebar width and the `Spacer(minLength: 0)` only takes up actual leftover space — name truncates only when the row is genuinely too narrow

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `ProfileRowView` layout: `.labelsHidden()` on Toggle, flat HStack with `Spacer(minLength: 0)`, outer `.frame(maxWidth: .infinity)`

## [2026-05-07] — Sidebar — Remove double-click inline rename trigger

**Type:** bugfix

### Changes

- Removed the double-click `TapGesture` from the profile name `Text` in `ProfileRowView` — it was preventing single-click row selection from reaching the List
- Inline rename UI (Text ↔ TextField transition driven by `editingProfileID`) is preserved; the rename flow is now triggered exclusively from the "Rinomina" context-menu item (introduced in task 11)
- Single click on the row now selects normally on macOS

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — removed `.simultaneousGesture(TapGesture(count: 2))` on profile name

## [2026-05-07] — Sidebar — Drag & drop reorder

**Type:** feature

### Changes

- Sidebar `List` converted to `List(selection:) { ForEach(profiles).onMove { ... } }` to enable native drag & drop reordering of profiles
- `.moveDisabled(profile.isReadOnly)` on each row prevents the Default profile from being dragged
- `onMove` rejects any drop with `destination == 0` so no profile can take the Default's first-position slot
- Reordering persists via the existing `ProfileStore.reorder(_:context:)`, which now also triggers `writeHosts(context:)` because per-profile sub-headers in `/etc/hosts` are sorted by `order`

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — List → ForEach + onMove + moveDisabled
- `HostFlow/Stores/ProfileStore.swift` — `reorder` now triggers `writeHosts`

## [2026-05-07] — Sidebar — Full context menu (Rinomina / Duplica / Elimina / Toggle)

**Type:** feature

### Changes

- Sidebar context menu extended: "Rinomina", "Duplica", "Elimina" (destructive), divider, "Attiva"/"Disattiva" (dynamic label)
- "Rinomina" sets `editingProfileID` and reuses the inline-rename flow built in task 09
- "Duplica" calls `ProfileStore.duplicate(_:context:)` and auto-selects the copy
- "Attiva"/"Disattiva" toggles `isActive` and triggers `writeHosts`
- Read-only guard applied to Rinomina, Elimina and Toggle (consistent with the global "Default profile is fully locked" decision); Duplica is always available since it produces an editable copy
- Added `ProfileStore.duplicate(_:context:)` — generates a unique name via `uniqueDuplicateName(base:among:)` (`<name> (copia)`, `<name> (copia 2)`, ... case-insensitive), copies all records with fresh UUIDs preserving each record's `isEnabled`, sets `isActive = false`, `isReadOnly = false`, `order = max + 1`

### Files modified

- `HostFlow/Stores/ProfileStore.swift` — `duplicate(_:context:)` + `uniqueDuplicateName` helper
- `HostFlow/Views/Sidebar/SidebarView.swift` — extended `.contextMenu` with all items

## [2026-05-07] — Sidebar row layout — name left, toggle right

**Type:** refactor

### Changes

- `ProfileRowView` reordered: profile name (with lock icon when read-only) on the left, switch toggle pinned to the right via `Spacer(minLength: 8)`
- Name truncates with ellipsis (`.lineLimit(1)` + `.truncationMode(.tail)`) when sidebar is narrow, lock icon and toggle remain visible

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — `ProfileRowView` layout reorder

## [2026-05-07] — Sidebar — Delete profile

**Type:** feature

### Changes

- Added `.contextMenu` on each sidebar row with a destructive "Elimina" item — disabled when the profile is read-only
- Added `.onDeleteCommand` on the sidebar `List` so the Delete key on a selected non-readonly profile triggers the same flow
- Both paths set `profileToDelete: Profile?`, which presents a `.confirmationDialog`: title "Eliminare profilo \"X\"?", message about cascade & irreversibility, destructive "Elimina" + cancel "Annulla"
- After confirmed deletion, auto-selects the next profile by `order` (or the previous one if the deleted was the last, or `nil` if it was the only one)
- Cascade delete of related `HostRecord`s already guaranteed by `Profile.records` `@Relationship(deleteRule: .cascade)` — no extra logic needed
- `ProfileStore.deleteProfile` already calls `writeHosts(context:)` → no change

### Files modified

- `HostFlow/Views/Sidebar/SidebarView.swift` — context menu, Delete shortcut, confirmation dialog, deletion helper with auto-select

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
