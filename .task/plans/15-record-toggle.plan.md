# Plan: Record Toggle with Visual Feedback

**Date:** 2026-05-07
**Type:** feature

## Summary

Add opacity visual feedback to disabled host records in the table view. The toggle functionality is already implemented with secondary color for disabled records, but we'll enhance it with reduced opacity (0.5) for a more pronounced visual distinction following macOS conventions.

## Steps

1. [x] Add `.opacity(record.isEnabled ? 1.0 : 0.5)` modifier to IP text cell — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
2. [x] Add `.opacity(record.isEnabled ? 1.0 : 0.5)` modifier to hostname text cell — `HostFlow/Views/ProfileDetail/ProfileDetailView.swift`
3. [x] Verify visual feedback works correctly by testing toggle on/off states

## Out of scope

- Debouncing of writeHosts calls (will be implemented in feature 22-hosts-trigger)
- Performance optimizations for rapid toggling
- Any changes to the toggle control itself (already correctly implemented)

## Open questions

- None
