# Plan: Migrazione MenuBarExtra a menu nativo macOS

**Date:** 2026-05-15
**Type:** refactor

## Original prompt
> Crea un task per la migrazione da popover menubar custom al popover nativo swift ios. So che i toggle per i profili non sono supportati, ma li vorrei gestire con un submenu che si apre quando si va sopra al profilo. Non voglio utilizzare un menu custom. Voglio il componente nativo iOS.

## Summary

Sostituire il `MenuBarExtra` attualmente in stile `.window` (popover SwiftUI custom con `MenuItemButtonStyle`, `MenuBarProfileRow`, `Toggle .switch`) con il menu nativo macOS (`.menuBarExtraStyle(.menu)`). Lo switch per attivare/disattivare il profilo, non rappresentabile come componente nativo nel menu top-level, viene spostato all'interno di un submenu che si apre in hover sulla voce del profilo. Il submenu contiene una sola voce `Toggle("Attivo", …)` che il menu nativo renderizza come item con checkmark. Sul padre (voce con submenu) viene mostrato un checkmark quando il profilo è attivo, per leggere lo stato senza dover aprire ogni submenu.

## Requirements

- **Stile MenuBarExtra:** `.menuBarExtraStyle(.menu)` in `HostFlowApp.swift`
- **Profilo non read-only:** voce `Menu` con label che mostra il nome + checkmark se `profile.isActive`. Submenu contiene una singola `Toggle("Attivo", isOn: $profile.isActive)` (il menu nativo la renderizza come checkmark item)
- **Profilo read-only:** voce piatta disabilitata con SF Symbol `lock.fill`, senza submenu
- **Click sul nome del profilo (voce padre):** nessuna azione; il submenu si apre solo in hover (comportamento NSMenu standard)
- **Ordine:** `@Query(sort: \Profile.order)` come oggi
- **Nessun header "Profili"**
- **Stato vuoto (nessun profilo):** la sezione profili è completamente omessa; il menu mostra direttamente le azioni in basso (nessun placeholder)
- **Azioni in basso:** "Apri Host Flow" (apre window + `NSApp.activate`), `SettingsLink`, "Esci" (con `keyboardShortcut("q", modifiers: .command)`), separate dai profili da un `Divider` quando esistono profili
- **MenuBarLabel:** invariato (icona + colore in base a `lastWriteError` / `activeProfiles`)
- **Write trigger:** al cambio di `profile.isActive` dal submenu, eseguire `try? context.save()` + `store.scheduleWrite(context: context)` come fa oggi `MenuBarProfileRow.onChange`
- **Codice da rimuovere:** `MenuItemButtonStyle`, `MenuItemButtonBody`, `MenuBarProfileRow` (sostituiti da componenti nativi). Il contenitore root `VStack(.frame(width:280))` viene rimosso

## Steps

### 1. Cambio stile MenuBarExtra
1. [ ] In [HostFlow/App/HostFlowApp.swift](HostFlow/App/HostFlowApp.swift), cambiare `.menuBarExtraStyle(.window)` → `.menuBarExtraStyle(.menu)`

### 2. Riscrittura MenuBarView
2. [ ] In [HostFlow/Views/MenuBar/MenuBarView.swift](HostFlow/Views/MenuBar/MenuBarView.swift) sostituire il body di `MenuBarView` con una struttura compatibile con il menu nativo:
   - `ForEach(profiles)` che produce, per ogni profilo:
     - se `profile.isReadOnly` → `Button` disabilitato con `Label(profile.name, systemImage: "lock.fill")` (nessuna azione)
     - altrimenti → `Menu` con label condizionale (checkmark+nome se attivo, solo nome se inattivo) il cui content è una singola `Toggle("Attivo", isOn: <binding>)` con `.onChange` che invoca `try? context.save()` + `store.scheduleWrite(context: context)`
   - Se la lista profili non è vuota: `Divider()` dopo il `ForEach`
   - Azioni bottom: `Button("Apri Host Flow") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }`, `SettingsLink { Text("Impostazioni…") }`, `Divider()`, `Button("Esci") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)`
3. [ ] Rimuovere `MenuItemButtonStyle`, `MenuItemButtonBody`, `MenuBarProfileRow` (non più utilizzati)
4. [ ] Rimuovere `@Environment(AppSettings.self)` da `MenuBarView` se non più usato (al momento serviva solo per il container custom)

### 3. Verifica binding profilo nel submenu
5. [ ] Estrarre se necessario una piccola view privata `MenuBarProfileMenu(profile: Profile)` con `@Bindable` per il `Toggle`, in modo che `isOn: $profile.isActive` funzioni dentro al `Menu`. Il `Toggle` deve invocare context save + `scheduleWrite` su cambio

### 4. Verifica build e UX in Xcode
6. [ ] Build da Xcode (target macOS 13+) e validare:
   - Menu nativo si apre sull'icona menubar (niente più popover-window)
   - Profili non read-only mostrano submenu al hover; click sulla voce padre non chiude il menu e non triggera azioni
   - `Toggle("Attivo")` nel submenu mostra checkmark in base allo stato e cambia stato al click
   - Checkmark sulla voce padre riflette `isActive` (visibile chiudendo e riaprendo il menu)
   - Profilo read-only ("Default") appare con `lock.fill`, disabilitato, senza submenu
   - Trigger scrittura `/etc/hosts` al toggle (controllabile via Console / `lastWriteError`)
   - "Apri Host Flow", "Impostazioni…", "Esci" funzionanti
   - Stato vuoto: nessuna voce di profilo, solo azioni
   - `MenuBarLabel` invariato (colore icona in base a profili attivi / errore)

## Out of scope

- Visualizzazione errori `lastWriteError` come voce del menu (oggi è solo nel colore dell'icona — invariato)
- Shortcut keyboard per attivare/disattivare singoli profili
- Riordinamento profili dal menubar
- Creazione profilo da menubar
- Indicatore di stato custom (oltre al checkmark nativo)
- Modifica del componente `MenuBarLabel`

## Open questions

Nessuna.

## Risks

- **Nested `Menu` in `MenuBarExtra(.menu)` su macOS 13:** il supporto a submenu in SwiftUI `Menu` annidato dentro `MenuBarExtra.menu` è documentato da macOS 13. Se in build dovesse non funzionare, fallback: voce piatta `Toggle` direttamente nel menu top-level per ogni profilo (perdendo il submenu ma usando comunque solo componenti nativi). Da valutare solo se la struttura corrente non si comporta come atteso
- **Renderizzazione checkmark sulla voce padre `Menu`:** in SwiftUI il `Menu` parent non ha API dedicata per "stato on/off". Soluzione: label condizionale con `Label(profile.name, systemImage: profile.isActive ? "checkmark" : "")` o spazio bianco quando inattivo, per allineamento. Da verificare visivamente in build; se la resa non è soddisfacente si può ricadere su solo nome (senza checkmark sul padre) — l'utente è disposto a perderlo se non è nativo bello
