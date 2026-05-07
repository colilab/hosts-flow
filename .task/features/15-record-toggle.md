# Task: Record — Toggle attiva/disattiva

## Obiettivo

Toggle nativo per ogni `HostRecord` nella tabella che attiva/disattiva il record. Disattivato → riga commentata in `/etc/hosts`.

## Requisiti

- `Toggle` con `.toggleStyle(.switch)` nella prima colonna
- Stato bindato a `record.isEnabled`
- Trigger `writeHosts` immediato (debounced — vedi 05-hosts-trigger)
- Visual feedback: testo grigio/striked-through quando disabled

## Checklist

- [ ] **Guard readonly**: se profilo `isReadOnly`, Toggle disabilitato (`.disabled(profile.isReadOnly)`)
- [ ] `TableColumn` toggle con `Toggle("", isOn: $record.isEnabled)`
- [ ] `.toggleStyle(.switch)` + `.controlSize(.small)`
- [ ] Larghezza colonna fissa (~50pt)
- [ ] `.foregroundStyle(record.isEnabled ? .primary : .secondary)` su IP/hostname text
- [ ] Listener su change → `ProfileStore.writeHosts(context:)` se profilo attivo

## Note tecniche

- Bindable `record` via `@Bindable var record: HostRecord`
- Performance: write hosts debounced 500ms per evitare scrittura su ogni toggle rapido
