# Task: Settings — Pulisci blocco /etc/hosts

## Obiettivo

Bottone in Settings (sezione "Avanzate" o simile) che rimuove il blocco gestito da Host Flow da `/etc/hosts`, lasciando il resto del file intatto.

## Requisiti

- Conferma alert: "Verrà rimosso il blocco Host Flow da /etc/hosts. I tuoi profili NON saranno cancellati."
- Esegue write con `block = ""` o rimuove completamente i marker
- Bottone destructive style (rosso)
- Disabilitato se blocco non presente

## Checklist

- [ ] Sezione Settings "Avanzate" con bottone "Pulisci /etc/hosts"
- [ ] `.buttonStyle(.borderedProminent)` `.tint(.red)` o stile destructive
- [ ] Alert conferma con due bottoni: Annulla / Rimuovi
- [ ] Action: `HostsFileManager.removeManagedBlock()` → write con block vuoto
- [ ] State: `hasManagedBlock` per disabilitare se non c'è nulla da pulire

## Note tecniche

- "Rimuovi" diverso da "scrivi blocco vuoto": rimuovi anche i marker per pulizia totale
- Riusa write atomico (vedi 05-hosts-write-atomic)
