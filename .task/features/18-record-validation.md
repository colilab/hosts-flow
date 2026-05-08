# Task: Record — Warning duplicati hostname

## Obiettivo

Validare l'edit di IP e Hostname come fatto in fase di inserimento e controllare anche l'eventuale duplicaizoen in fase di edit.
Mostrare un warning visivo (non blocking) quando un hostname è duplicato all'interno dello stesso profilo o tra profili attivi.

## Requisiti

- Validazione blocca il salvataggio (devo avere IP e Hostname coerenti)
- Duplicazione non blocca il salvataggio (è valido avere duplicati per casi avanzati)
- Icona warning SF Symbol `exclamationmark.triangle` con tooltip per duplicazione
- Check duplicazione effettuato all'apertura del profilo + dopo edit/add

## Checklist

### Validazione bloccante (già implementata)
- [x] Validazione IP/hostname via `HostValidator.validateRecord` in `AddRecordSheet` con disable bottone + errore inline (task 03)
- [x] Validazione IP/hostname in `EditRecordSheet` (modale, task 03)
- [x] Validazione single-field in inline edit (Table cells) con border rosso + commit bloccato su invalid (task 14)

### Warning duplicati (questo task)
- [ ] Computed `duplicatedHostnames: Set<String>` in `ProfileDetailView`
- [ ] Group by hostname (case-insensitive) → keep quelli con count > 1
- [ ] Aggiungere icona `exclamationmark.triangle` nella colonna hostname se duplicato
- [ ] Tooltip via `.help`: "Hostname duplicato — l'ultimo record attivo prevarrà"
- [ ] Cross-profile: includere record `isEnabled` di altri profili `isActive`

## Note tecniche

- `.help("...")` per tooltip
- Cross-profile: query `Profile` con `isActive == true` e flatten records
