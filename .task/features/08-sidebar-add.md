# Task: Sidebar — Aggiungi profilo

## Obiettivo

Bottone "+" nella sidebar che apre uno sheet/alert per inserire il nome del nuovo profilo, con validazione (non vuoto, non duplicato).

## Requisiti

- UI nativa (Alert con TextField o Sheet)
- Validazione live: pulsante "Crea" disabilitato se nome vuoto o duplicato
- Profilo creato con `isActive = false`, order corretto (vedi 02-data-ordering)
- Auto-select del nuovo profilo nella sidebar

## Checklist

- [ ] Bottone toolbar/footer sidebar con SF Symbol `plus`
- [ ] Alert/Sheet "Nuovo profilo" con TextField + bottoni Annulla/Crea
- [ ] Check duplicato case-insensitive su `Profile.name`
- [ ] Errore inline "Esiste già un profilo con questo nome"
- [ ] Su create: `ProfileStore.addProfile` + auto-select via binding `selectedProfileID`
- [ ] Focus automatico sul TextField all'apertura

## Note tecniche

- Per Alert con TextField: `.alert("Nuovo profilo", isPresented:)` + `TextField` nei children (macOS 12+)
- In alternativa Sheet con Form per più controllo UX
