# Task: Style cleanup — Allineamento spacing/typography alle convenzioni

## Obiettivo

Allineare i punti residui di styling alle regole di `.claude/conventions.md`: spacing in multipli di 4/8pt, niente font size fisse, niente styling ridondante per stato disabled. Nessuna decisione di design: sostituzioni puntuali a valori conformi.

## Requisiti

- Tutti gli `spacing:` e `.padding()` con valori non in {0, 4, 8, 12, 16, 20, 24, ...} sostituiti con il multiplo di 4 più vicino, scegliendo il valore che preserva la densità visiva attuale.
- Nessun `.font(.system(size: N))` con `N` letterale: usare uno stile semantico (`.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.caption`, ecc.) oppure SF Symbol image scale.
- Per i record disabilitati nella tabella, eliminare il doppio styling `.foregroundStyle(.secondary) + .opacity(0.5)` → tenere solo `.foregroundStyle(.secondary)`.

## Checklist

- [ ] `SidebarView.swift` `ProfileRowView`: `HStack(spacing: 6)` → `HStack(spacing: 8)`
- [ ] `SidebarView.swift` `ProfileRowView`: `.padding(.vertical, 2)` → `.padding(.vertical, 4)`
- [ ] `ProfileDetailView.swift` `toolbar`: `.padding(.vertical, 10)` → `.padding(.vertical, 8)`
- [ ] `AddProfileSheet.swift`: `VStack(alignment: .leading, spacing: 6)` (form field + errore) → `spacing: 8`
- [ ] `SettingsView.swift` "Pulisci /etc/hosts": `VStack(alignment: .leading, spacing: 2)` → `spacing: 4`
- [ ] `HelperOnboardingSheet.swift`: `Image(systemName: "lock.shield").font(.system(size: 32))` → rimuovere `.font(...)` e usare `.font(.largeTitle)` (≈34pt nativo, vicinissimo a 32)
- [ ] `ProfileDetailView.swift` colonne IP e Hostname: rimuovere `.opacity(record.isEnabled ? 1.0 : 0.5)` (mantenere `.foregroundStyle(record.isEnabled ? .primary : .secondary)`)
- [ ] Build di verifica

## Note tecniche

- Out of scope: named colors `.red` / `.orange` per validazione e warning (interpretati come semantic, in linea con `tint(.red)` già usato in SettingsView).
- Out of scope: `.frame(width:)` sulle sheet (pattern nativo macOS per dialog modali).
- Out of scope: `TableColumn.width(...)` (necessari al layout tabella).
- `.padding(20)` su sheet root è multiplo di 4 → conforme, non modificare.
- Nessuna modifica funzionale: solo costanti di styling.

---

**Completed:** 2026-05-15

**Resolution:** Applicate tutte le 7 sostituzioni come da checklist. Build SUCCEEDED.
