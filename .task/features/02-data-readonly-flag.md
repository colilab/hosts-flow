# Task: Profile — Flag readonly (system profile)

## Obiettivo

Aggiungere a `Profile` un flag `isReadOnly: Bool` che marca i profili "di sistema" (es. Default seed da `/etc/hosts`) come non modificabili: nome immutabile, record non aggiungibili/modificabili/cancellabili, profilo non eliminabile. Resta toggleable (`isActive`) e duplicabile.

## Requisiti

- Campo `isReadOnly: Bool = false` su `Profile` (default false per profili user-created)
- Computed `isEditable: Bool { !isReadOnly }` per uso nelle view
- Migration SwiftData automatica (campo opzionale con default)
- Comportamento readonly:
  - **bloccato**: rinomina, elimina profilo, add/edit/delete record, toggle record `isEnabled`
  - **consentito**: toggle profilo `isActive`, duplica (crea copia con `isReadOnly = false`), reorder
- UI feedback: icona lock SF Symbol `lock.fill` accanto al nome nella sidebar
- Tooltip: "Profilo di sistema — non modificabile. Duplica per creare una copia editabile."

## Checklist

- [ ] Aggiungere `var isReadOnly: Bool = false` a `Profile`
- [ ] Computed `var isEditable: Bool { !isReadOnly }`
- [ ] Verificare migration SwiftData: aprire app con vecchio store → no crash
- [ ] In `SidebarView` ProfileRow: SF Symbol `lock.fill` se readonly (size piccola, color secondary)
- [ ] `.help("Profilo di sistema — duplica per modificare")` su row readonly
- [ ] Esporre helper `ProfileStore.canEdit(_ profile: Profile) -> Bool` (ridondante ma comodo per testing)
- [ ] Test: profilo readonly creato → tutte le UI di edit risultano disabilitate (verificato in task successivi)

## Note tecniche

- Default seed dal task successivo crea il Default con `isReadOnly = true`
- I check di guard (`guard profile.isEditable else { return }`) sono distribuiti nei task sidebar/record affetti — questo task introduce solo il modello + UI marker
- Considerare `@Transient` no — deve persistere
- Duplica di un profilo readonly produce un profilo NON readonly (copia editabile)
