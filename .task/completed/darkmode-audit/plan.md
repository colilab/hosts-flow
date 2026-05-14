# Plan: Dark Mode — Audit visuale

**Date:** 2026-05-14
**Type:** chore

## Original prompt
> Eseguire l'audit dark mode descritto in `.task/features/32-darkmode-audit.md`: verificare che ogni view dell'app sia leggibile/usabile in dark mode, individuare hardcoded colors o asset non-adaptive, e fixare i problemi trovati.

## Summary
Audit statico di tutte le view SwiftUI per identificare colori hardcoded, asset non-adaptive e pattern problematici per dark mode. Esito: il codice è già conforme alle convenzioni — tutti i colori usati sono semantic (SwiftUI o NSColor adaptive). Restano due interventi opzionali (variant dark dell'AppIcon su Sonoma+ e revisione del pattern white-on-accent del MenuBarView), entrambi non bloccanti.

## Findings (per view)

### `SidebarView` — [HostFlow/Views/Sidebar/SidebarView.swift](HostFlow/Views/Sidebar/SidebarView.swift)
- ✅ Usa `List` con `.listStyle(.sidebar)` → background nativo, divider nativi
- ✅ `Image(systemName: "lock.fill").foregroundStyle(.secondary)` — semantic
- ✅ `SettingsLink` con `Image("gear").foregroundStyle(.secondary)` — semantic
- ✅ Nessun colore hardcoded

### `ProfileDetailView` — [HostFlow/Views/ProfileDetail/ProfileDetailView.swift](HostFlow/Views/ProfileDetail/ProfileDetailView.swift)
- ✅ Search bar usa `Color(nsColor: .controlBackgroundColor)` e `.separatorColor` → AppKit adaptive
- ✅ `Table` nativa → header/row/selection automatici in dark
- ✅ `.foregroundStyle(record.isEnabled ? .primary : .secondary)` — semantic
- ✅ `.foregroundStyle(.orange)` per warning duplicato — semantic SwiftUI (adatta in dark)
- ✅ `ContentUnavailableView` nativo → empty state HIG-compliant

### `MenuBarView` — [HostFlow/Views/MenuBar/MenuBarView.swift](HostFlow/Views/MenuBar/MenuBarView.swift)
- ✅ `MenuBarLabel` usa `Image("MenuBarIcon")` con `symbolRenderingMode(.hierarchical)` + `.foregroundStyle(...)` adaptive (`.red` errore / `.secondary` idle / `Color(nsColor: .controlAccentColor)` attivo)
- ✅ `MenuBarIcon` è un `.symbolset` (SVG template) → si tinge automaticamente per light/dark
- ⚠️ `MenuItemButtonStyle` (riga 117-120): `Color.white` su `Color.accentColor` quando highlighted. È il pattern standard macOS per menu hover (testo bianco su accent fill funziona in entrambi i temi), ma su accent chiari (es. giallo) il contrasto può essere subottimale. **Decisione:** mantenere — è il comportamento atteso del menu nativo macOS.
- ✅ Empty state usa `.foregroundStyle(.secondary)` e SF Symbol

### `SettingsView` + `HelperSettingsSection` — [HostFlow/Views/Settings/](HostFlow/Views/Settings/)
- ✅ `Form` nativa → background/grouping automatici
- ✅ `.foregroundStyle(.secondary)` per descrizioni
- ✅ `.tint(.red)` su pulsante destructive — semantic
- ✅ `.foregroundStyle(.red)` su stati errore — semantic

### `AddRecordSheet` + `EditRecordSheet` — [HostFlow/Views/ProfileDetail/](HostFlow/Views/ProfileDetail/)
- ✅ Sheet native → background system
- ✅ `.foregroundStyle(.red)` per messaggi validation — semantic

### `AddProfileSheet` — [HostFlow/Views/Sidebar/AddProfileSheet.swift](HostFlow/Views/Sidebar/AddProfileSheet.swift)
- ✅ `.foregroundStyle(.red)` per validation — semantic

### `HelperOnboardingSheet` — [HostFlow/Views/Onboarding/HelperOnboardingSheet.swift](HostFlow/Views/Onboarding/HelperOnboardingSheet.swift)
- ✅ `.foregroundStyle(.tint)` e `.secondary` — semantic

### Assets — [HostFlow/Resources/Assets.xcassets/](HostFlow/Resources/Assets.xcassets/)
- ✅ `MenuBarIcon.symbolset` → template, adatta automaticamente
- ✅ `AppIcon.appiconset`: nessuna variante dark possibile — verificato il 2026-05-13 (vedi CHANGELOG) che `appearances: luminosity` su `idiom: mac` viene **silenziosamente ignorato** da `actool`. L'icona attuale è progettata per funzionare in entrambi i temi. Tinted icons macOS 15+ richiederebbero il nuovo formato `.icon` (Icon Composer) — fuori scope.

## Steps

Nessun fix di codice richiesto: l'audit conferma che le convenzioni dark-mode del progetto (`conventions.md` § Design HIG) sono già rispettate.

1. [x] Audit `SidebarView` — nessun problema
2. [x] Audit `ProfileDetailView` (table + search bar) — nessun problema
3. [x] Audit `MenuBarView` popover — pattern white-on-accent legittimo, mantenuto
4. [x] Audit `SettingsView` + `HelperSettingsSection` — nessun problema
5. [x] Audit `AddRecordSheet` + `EditRecordSheet` + `AddProfileSheet` — nessun problema
6. [x] Audit `HelperOnboardingSheet` + empty states + alerts — nessun problema
7. [x] Audit asset catalog — `MenuBarIcon` template OK; `AppIcon` dark variant rimandato

## Out of scope
- Verifica visuale runtime (build + screenshot light/dark) — esplicitamente esclusa: solo analisi statica
- Migrazione `AppIcon` al formato `.icon` di Icon Composer per supportare tinted icons macOS 15+
- Refactor del pattern hover di `MenuItemButtonStyle` (comportamento atteso macOS)

## Open questions
Nessuna.

---

**Completed:** 2026-05-14

**Resolution:** Static audit completed — no code changes required. All views already use semantic/adaptive colors per project conventions. Findings documented per-view in this plan.
