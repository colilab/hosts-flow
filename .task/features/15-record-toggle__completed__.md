# Task: Record — Toggle attiva/disattiva

## Obiettivo

Toggle nativo per ogni `HostRecord` nella tabella che attiva/disattiva il record. Disattivato → riga commentata in `/etc/hosts`.

## Requisiti

- `Toggle` con `.toggleStyle(.switch)` nella prima colonna
- Stato bindato a `record.isEnabled`
- Trigger `writeHosts` immediato (debounced — vedi 05-hosts-trigger)
- Visual feedback: testo grigio/striked-through quando disabled

## Checklist

- [x] **Guard readonly**: se profilo `isReadOnly`, Toggle disabilitato (`.disabled(profile.isReadOnly)`)
- [x] `TableColumn` toggle con `Toggle("", isOn: $record.isEnabled)`
- [x] `.toggleStyle(.switch)` + `.controlSize(.small)`
- [x] Larghezza colonna fissa (~50pt)
- [x] `.foregroundStyle(record.isEnabled ? .primary : .secondary)` su IP/hostname text
- [x] Listener su change → `ProfileStore.writeHosts(context:)` se profilo attivo

## Note tecniche

- Bindable `record` via `@Bindable var record: HostRecord`
- Performance: write hosts debounced 500ms per evitare scrittura su ogni toggle rapido

---

**Completed:** 2026-05-07

**Resolution:** Enhanced visual feedback for disabled records by adding opacity (0.5) modifier in addition to existing secondary color styling
