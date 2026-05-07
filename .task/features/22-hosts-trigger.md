# Task: /etc/hosts — Trigger scrittura debounced

## Obiettivo

Scrivere `/etc/hosts` automaticamente dopo ogni modifica rilevante (toggle profilo/record, add/edit/delete record, reorder), con debounce per evitare write multipli.

## Requisiti

- Debounce: 500ms dall'ultima modifica
- Coalescing: modifiche multiple in burst → 1 sola write
- Loading indicator nella UI (sidebar o status icon menu bar) durante write
- Log dell'ultimo write riuscito (timestamp)

## Checklist

- [ ] `ProfileStore` con `private var writeDebouncer: Task<Void, Never>?`
- [ ] `func scheduleWrite(context: ModelContext)`: cancella task esistente + crea nuovo con `Task.sleep(500ms)` + `writeHostsImmediate`
- [ ] Hook chiamate `scheduleWrite` su:
  - profile.isActive change
  - record.isEnabled change
  - record add/edit/delete
  - profile delete (se era active)
  - reorder (se cambia ordering profili attivi)
- [ ] State `@Observable var isWritingHosts: Bool` + `lastWriteAt: Date?`
- [ ] `lastWriteAt` esposto per il watcher (task hosts-watch-external) — serve per distinguere write nostri da edit esterni
- [ ] Cancellation safe: se app chiude, ultima modifica deve persistere

## Note tecniche

- Considera `Combine` debounce su published flag (più ergonomico) o Task-based (più moderno)
- Test concurrent: 5 toggle rapidi in 200ms → solo 1 write effettiva
