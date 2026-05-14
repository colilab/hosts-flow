# Task: Dark Mode — Audit visuale

## Obiettivo

Verificare che ogni view dell'app sia leggibile/usabile in dark mode, individuando hardcoded colors o asset non-adaptive.

## Requisiti

- Tutte le view ispezionate in light + dark + system (se cambia mid-session)
- Check colori: solo semantic (`.primary`, `.secondary`, `Color(nsColor: .controlAccentColor)`)
- Check icone: SF Symbols si adattano automaticamente
- Asset custom: avere variant dark se presenti

## Checklist

- [ ] Audit `SidebarView` (background, divider, text contrast)
- [ ] Audit `ProfileDetailView` table (header, row alternato, selection)
- [ ] Audit `MenuBarView` popover
- [ ] Audit `SettingsView` form
- [ ] Audit `AddRecordSheet` + `EditRecordSheet`
- [ ] Audit empty states + error alerts
- [ ] Lista in commento di hardcoded colors trovati → fixare uno per uno

## Note tecniche

- Toggle dark mode rapido durante test: System Settings o `.preferredColorScheme(.dark)` modifier temporaneo
- Toolbar con `Color.red`, `Color.blue` etc → sostituire con `.tint(.accentColor)`
