# Task: Validazione IP + Hostname

## Obiettivo

Validare i campi `ip` e `hostname` di `HostRecord` prima di persistere, sia su create che update.

## Requisiti

- Supporto IPv4 e IPv6
- Hostname conforme a RFC 1123 (label 1–63 char, alfanumerici + `-`, separatori `.`, no leading/trailing `-`)
- Errori user-facing in italiano

## Checklist

- [ ] Helper `HostValidator` in `Helpers/`
  - [ ] `static func isValidIPv4(_ s: String) -> Bool`
  - [ ] `static func isValidIPv6(_ s: String) -> Bool`
  - [ ] `static func isValidIP(_ s: String) -> Bool` (combina IPv4/IPv6)
  - [ ] `static func isValidHostname(_ s: String) -> Bool`
- [ ] Enum `ValidationError: LocalizedError` con casi `invalidIP`, `invalidHostname`, `empty`
- [ ] Integrazione in `AddRecordSheet` (disabilita "Salva" se invalid + messaggio inline)
- [ ] Integrazione in `EditRecordSheet`
- [ ] Trim whitespace prima della validazione

## Note tecniche

- IPv4: usa `inet_pton(AF_INET, ...)` per robustezza
- IPv6: usa `inet_pton(AF_INET6, ...)`
- Hostname regex: `^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$`

---

**Completed:** 2026-05-07

**Resolution:** Helper `HostValidator` con validazione IPv4/IPv6 (via `inet_pton`) e hostname RFC 1123, enum `ValidationError: LocalizedError` con messaggi italiani, integrato in `AddRecordSheet` e `EditRecordSheet` con disable bottone su invalid e messaggio inline. Trim whitespace su salvataggio.
