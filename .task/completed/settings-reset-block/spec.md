# Task: Settings — Pulisci blocco /etc/hosts e profili Host Flow

## Obiettivo

Bottone in Settings (sezione "Avanzate") che rimuove tutti i profili gestiti da Host Flow e i loro record, ripristina il profilo Default (read-only) come unico attivo e pulisce il blocco gestito da `/etc/hosts`.

## Requisiti

- Conferma alert: "Verranno rimossi tutti i profili Host Flow e i loro record. Il blocco verrà rimosso da /etc/hosts. L'operazione è irreversibile."
- Cancellazione cascade di tutti i profili non read-only (e dei loro `HostRecord`)
- Profilo Default (read-only) mantenuto e forzato a `isActive = true` come unico profilo attivo
- Esegue `HostsFileManager.removeManagedBlock()` (rimuove anche i marker)
- Bottone destructive style (rosso)
- Disabilitato se blocco non presente

## Checklist

- [x] Sezione Settings "Avanzate" con bottone "Pulisci"
- [x] `.buttonStyle(.borderedProminent)` `.tint(.red)`
- [x] Alert conferma con due bottoni: Annulla / Rimuovi
- [x] Action: cancella profili non read-only, attiva Default, chiama `HostsFileManager.removeManagedBlock()`
- [x] State: `hasManagedBlock` per disabilitare se non c'è nulla da pulire
- [x] Feedback visivo: i profili scompaiono automaticamente dalla sidebar (SwiftData reattivo)

## Note tecniche

- Il profilo Default è `isReadOnly: true`, auto-seedato da `/etc/hosts` e tenuto in sync dal watcher (`syncDefaultFromFile`). Non va cancellato.
- "Rimuovi" diverso da "scrivi blocco vuoto": rimuovi anche i marker per pulizia totale
- Riusa write atomico (vedi 05-hosts-write-atomic)
