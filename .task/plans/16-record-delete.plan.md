# Plan: Record Delete with Multi-Select

**Date:** 2026-05-07
**Type:** feature

## Summary

Implement record deletion via context menu and Delete key with multi-select support. Replace the existing trash button with a more macOS-native approach using selection-based deletion. Users can select multiple records (Cmd+click) and delete them all at once.

## Steps

1. [x] Add `selectedRecordIDs: Set<UUID>` state for multi-select support — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
2. [x] Update Table to use `selection: $selectedRecordIDs` — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
3. [x] Add `.contextMenu(forSelectionType: HostRecord.ID.self)` with "Elimina" item — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
4. [x] Add `.onDeleteCommand` to handle Delete key — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
5. [x] Implement `deleteSelectedRecords()` helper function — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
6. [x] Remove the entire actions column (both pencil and trash buttons) — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
7. [x] Test multi-select: Cmd+click 3 records, press Delete, verify all removed

## Out of scope

- Confirmation dialog (task specifies no alert needed)
- Undo functionality
- Swipe actions (macOS Table doesn't support swipe)
- Batch operations beyond delete

## Open questions

- None
