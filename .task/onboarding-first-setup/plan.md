# Plan: First-run onboarding per organizzare i record di /etc/hosts

**Date:** 2026-05-25
**Type:** feature

## Original prompt
> voglio creare un nuovo task per migliorare l'onboarding di un primo avvio dell'applicazione. Spiego il "problema" a livello UX: quando l'utente scarica, installa e avvia l'applicazione per la prima volta, si ritrova un unico profilo "Default" con tutti i record del file "/etc/hosts", sia quelli di sistema sia quelli custom. In questo caso, ritrovo tutti i record bloccati e disabilitati. In questo caso, l'utente potrebbe avere già creato i profili in un'altra applicazione (che vuole rimpiazzare con HostFlow) oppure ha modificato a mano il file. In ogni caso, avere tutti i record bloccati in read only sul profilo di default, è un po' limitante. L'utente non può spostarli o organizzarli da interfaccia.
>
> L'unico modo che avrebbe l'utente per organizzare e ricreare i profili è duplicare il file etc/hosts e caricarlo a mano, oppure trasformarlo in un json. Tutti sistemi poco UX friendly.
>
> Quello che servirebbe è una sorta di onboarding iniziale per organizzare i record che sono stati trovati. Hai compreso la problematica UX? Ti vengono in mente soluzioni?

## Summary

Al primo avvio (solo nuova installazione), se in `/etc/hosts` esistono record custom (cioè non appartenenti alla whitelist di sistema), mostriamo un wizard che propone di importarli in un profilo editabile "Imported" e di rimuoverli dalla parte unmanaged di `/etc/hosts` — di fatto facendo prendere a HostFlow il pieno possesso del file. Il profilo `Default` read-only continua a esistere come specchio della parte unmanaged (che dopo l'onboarding contiene solo entry di sistema). Utenti esistenti 1.0.x non vedono il wizard perché il DB è già popolato.

## Decisioni chiave (esito grilling)

- **Opzione B**: HostFlow assume il possesso di `/etc/hosts` durante l'onboarding (sposta i custom dentro al blocco gestito, lascia fuori solo le entry di sistema).
- **Opzione α**: i record custom finiscono tutti in un singolo profilo `Imported` (editabile, active di default). L'utente li riorganizza dopo con gli strumenti esistenti.
- **Trigger**: solo se DB vuoto (`Profile` count == 0) E esistono record custom in `/etc/hosts`. Mac vergine (0 custom) → nessun wizard, seeding silenzioso del solo `Default` read-only come oggi.
- **Whitelist sistema**: match esatto su `(ip, hostname)`. Set iniziale:
  - `127.0.0.1 localhost`
  - `255.255.255.255 broadcasthost`
  - `::1 localhost`
  - `fe80::1%lo0 localhost`
- **Profilo `Default` post-onboarding**: invariato concettualmente. Resta read-only, watcher attivo, mirror della parte unmanaged. Dopo l'onboarding mostra solo le system entries.
- **Profilo `Imported`**: editabile, active di default (preserva la risoluzione DNS attuale dell'utente).
- **Bottone "Importa da JSON"** nel welcome screen come azione secondaria, con `?` che apre popover con descrizione formato + bottone "Scarica esempio". Il formato supportato è quello nativo HostFlow (`ExportPayload`), NON iHosts. Niente parser iHosts in questo task.
- **Bottone "Inizia da zero"** nel welcome (azione terziaria): chiude il wizard senza scrivere `/etc/hosts`, lascia il `Default` read-only a fare il mirror di tutto come oggi (comportamento legacy 1.0.x).
- **Helper install**: lazy. Il wizard arriva fino a "Applica"; al click si tenta la scrittura, se `helperMissing` parte il `HelperOnboardingSheet` esistente, l'utente installa, poi riscrive.

## Steps

1. [ ] Estendere whitelist sistema in un nuovo enum/struct — `HostFlow/Helpers/SystemHostEntries.swift` con il set delle entry note e un metodo `classify(ParsedHostRecord) -> .system | .custom`.
2. [ ] Aggiungere a `HostsFileParser` un helper `parseSystemHostsClassified() -> (system: [ParsedHostRecord], custom: [ParsedHostRecord])` — `HostFlow/Helpers/HostsFileParser.swift`.
3. [ ] Aggiungere a `HostsFileManager` un metodo `pruneUnmanagedKeepingSystem() async throws` che riscrive `/etc/hosts` lasciando in unmanaged SOLO le system entries (in ordine canonico) + ricostruisce il blocco managed dai profili attivi — `HostFlow/Helpers/HostsFileManager.swift`. Internamente usa lo stesso XPC client.
4. [ ] In `ProfileStore.seedIfNeeded`: rilevare presenza di record custom e in tal caso NON popolare subito il `Default` con i custom; popolarlo solo con system entries (o lasciarlo vuoto se file non leggibile). Aggiungere un flag `pendingOnboardingCustoms: [ParsedHostRecord]` esposto allo store per consumarlo dalla view del wizard. Mantenere il comportamento legacy (popolare tutto in Default read-only) come fallback quando l'utente sceglie "Inizia da zero" — `HostFlow/Stores/ProfileStore.swift`.
5. [ ] Aggiungere a `ProfileStore` due nuovi metodi:
   - `completeOnboardingImporting(customs:profileName:context:)` → crea profilo `Imported` (editabile, active), inserisce i record custom dentro, poi chiama `pruneUnmanagedKeepingSystem` via writer.
   - `completeOnboardingStartEmpty(context:)` → ripopola il `Default` read-only con tutti i record (system + custom) come comportamento 1.0.x; nessuna scrittura su `/etc/hosts`.
6. [ ] Creare nuova vista wizard root — `HostFlow/Views/Onboarding/FirstRun/FirstRunOnboardingSheet.swift`. Due step: Welcome → Preview. Sheet non-dismissable (l'utente deve scegliere un percorso o premere "Inizia da zero").
7. [ ] Creare `HostFlow/Views/Onboarding/FirstRun/FirstRunWelcomeView.swift`. Tre azioni:
   - Primaria: **"Continua"** → step Preview
   - Secondaria: **"Importa da JSON"** + `?` → apre `JSONFormatPopover`; al click su "Scegli file" usa lo stesso flusso `ImportJSONService` esistente, alla conferma chiude l'onboarding senza creare l'Imported.
   - Terziaria: **"Inizia da zero"** (link style) → conferma con alert, poi `completeOnboardingStartEmpty`.
8. [ ] Creare `HostFlow/Views/Onboarding/FirstRun/FirstRunPreviewView.swift`. Mostra:
   - Conteggio record custom trovati.
   - `TextField` per il nome del profilo (default `Imported`, modificabile).
   - Lista compatta dei record che verranno importati (scrollabile, read-only nel preview).
   - Sezione "Entry di sistema (resteranno fuori dal blocco gestito)" con la lista whitelisted.
   - Bottoni: **Indietro** | **Applica**. Al click su Applica → `completeOnboardingImporting(...)` → se `helperMissing` parte il flow helper esistente.
9. [ ] Creare componente riusabile `HostFlow/Views/Components/JSONFormatPopover.swift` (o `Views/Settings/JSONFormatHelpButton.swift`) — popover con: descrizione testuale del formato, esempio JSON inline (in `Text` con `.monospaced()`), bottone "Scarica esempio" che salva un file `hostflow-example.json` in `~/Downloads` tramite `NSSavePanel`. Riusabile per essere innestato sia nel welcome che nelle Settings.
10. [ ] Innestare `JSONFormatHelpButton` accanto al bottone "Importa da JSON" nelle Settings — `HostFlow/Views/Settings/SettingsView.swift` (e/o `ImportProfileSheet.swift` se la trigger sta lì).
11. [ ] Wire-up in `ContentView`: presentare `FirstRunOnboardingSheet` quando `store.pendingOnboardingCustoms` non è vuoto. Lo sheet si chiude quando lo store consuma il pending — `HostFlow/App/ContentView.swift`.
12. [ ] Localizzazione: aggiungere tutte le nuove stringhe (welcome title/body, preview labels, popover content, sample download confirm, ecc.) in `Localizable.xcstrings` per tutte le lingue già supportate (en, it, ...).
13. [ ] Smoke test manuale:
    - DB fresco + /etc/hosts con custom → wizard appare, "Continua" → Applica → /etc/hosts unmanaged ridotto a system entries, profilo Imported creato con i custom attivi, Default mostra solo system.
    - DB fresco + /etc/hosts solo system → nessun wizard, comportamento attuale.
    - DB fresco + click "Inizia da zero" → nessuna scrittura, Default read-only popolato con tutti i record come 1.0.x.
    - DB fresco + click "Importa da JSON" con file valido → profili importati, wizard chiuso, /etc/hosts non viene "pruned" (l'utente l'ha scelto esplicitamente: niente take-ownership in questo branch).
    - DB già popolato (simulo update da 1.0.x) → nessun wizard.
    - Helper non installato all'Applica → `HelperOnboardingSheet` parte, dopo install la scrittura viene completata.

## Out of scope

- Parser per JSON di iHosts o altre app di terzi. Sarà task separato dopo aver studiato il loro formato.
- Comando "Riorganizza /etc/hosts" in Settings per utenti esistenti 1.0.x (lo lascio come follow-up; serve a chi ha già il Default popolato e vuole lanciare il wizard a posteriori).
- Drag-drop multi-bucket nel wizard (opzione β scartata).
- Drift detection avanzato sul Default post-onboarding (per ora solo il watcher esistente che già fa il mirror, niente notifiche).
- Schermata "diff visuale before/after" di `/etc/hosts` — in Preview mostriamo solo conteggi e lista record, non il diff completo del file.

## Open questions

(nessuna)
