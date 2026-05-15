# Plan: Export profilo come testo /etc/hosts

**Date:** 2026-05-15
**Type:** feature
**Ref:** [.task/features/34-export-hosts-format.md](.task/features/34-export-hosts-format.md)

## Original prompt
> .task/features/34-export-hosts-format.md — Esportare il profilo selezionato come testo nel formato `/etc/hosts` (singolo profilo), con opzioni "Copia negli appunti" e "Salva su file…". Toolbar action in `ProfileDetailView`.

## Summary
Aggiungere un'azione "Esporta" come `Menu` nella toolbar di `ProfileDetailView`, con due voci: "Copia negli appunti" e "Salva su file…". L'export produce un blocco testuale nel formato `/etc/hosts` per il singolo profilo (header `# <Profile Name>` + record, disabilitati commentati). Il profilo readonly **Default** non è esportabile (menu disabilitato); i profili vuoti lo sono. Feedback: overlay HUD transiente (1.5s) "Copiato!" / "Salvato" per il successo, `.alert` nativo per gli errori di scrittura file.

## Decisioni prese durante il grilling
- **Posizione UI:** singolo `Menu` "Esporta" nella toolbar del detail (no context menu sidebar).
- **Profili readonly:** Default **non** esportabile (menu disabilitato).
- **Profili vuoti:** esportabili (producono solo l'header).
- **Feedback successo:** overlay HUD transiente 1.5s (no alert).
- **Feedback errore (save):** `.alert` nativo.
- **Lingua:** stringhe nuove vanno in `Localizable.xcstrings` (EN base + IT).

## Steps

### 1. Logica di formattazione
1. [ ] [`HostFlow/Helpers/HostsFileManager.swift`](HostFlow/Helpers/HostsFileManager.swift) — aggiungere metodo pubblico `func formatProfile(_ profile: Profile) -> String`. Output: `"# \(profile.name)\n"` seguito da `"\(ip) \(hostname)"` (o `"# \(ip) \(hostname)"` per record disabilitati), separati da `\n`, con newline finale. Stesso ordinamento dei record di `buildBlock` (ordine SwiftData naturale).

### 2. Stringhe localizzate
2. [ ] [`HostFlow/Resources/Localizable.xcstrings`](HostFlow/Resources/Localizable.xcstrings) — aggiungere chiavi (EN / IT):
   - `profile.detail.export.menu` → "Export" / "Esporta"
   - `profile.detail.export.copy` → "Copy to clipboard" / "Copia negli appunti"
   - `profile.detail.export.save` → "Save to file…" / "Salva su file…"
   - `profile.detail.export.copied` → "Copied" / "Copiato"
   - `profile.detail.export.saved` → "Saved" / "Salvato"
   - `profile.detail.export.save.panel.title` → "Export profile" / "Esporta profilo"
   - `profile.detail.export.save.error.title` → "Failed to save file" / "Salvataggio non riuscito"

### 3. Action handler nel detail
3. [ ] [`HostFlow/Views/ProfileDetail/ProfileDetailView.swift`](HostFlow/Views/ProfileDetail/ProfileDetailView.swift):
   - Aggiungere stato `@State private var hudMessage: LocalizedStringKey?` e `@State private var saveError: String?`
   - In `toolbar` aggiungere un `Menu` "Esporta" prima del bottone "Aggiungi record":
     ```swift
     Menu {
         Button("profile.detail.export.copy") { copyToClipboard() }
         Button("profile.detail.export.save") { saveToFile() }
     } label: {
         Label("profile.detail.export.menu", systemImage: "square.and.arrow.up")
     }
     .menuStyle(.borderlessButton)
     .controlSize(.small)
     .disabled(profile.isReadOnly)
     ```
     Disabilitazione su `profile.isReadOnly` (copre il caso Default).
   - `private func copyToClipboard()`:
     ```swift
     let text = HostsFileManager.shared.formatProfile(profile)
     NSPasteboard.general.clearContents()
     NSPasteboard.general.setString(text, forType: .string)
     showHUD("profile.detail.export.copied")
     ```
   - `private func saveToFile()`:
     - `NSSavePanel()` con `allowedContentTypes = [.plainText]`, `nameFieldStringValue = defaultFilename`, `title = String(localized: "profile.detail.export.save.panel.title")`
     - `panel.begin { response in ... }` (async, non bloccante): on `.OK`, scrivere `text.write(to: url, atomically: true, encoding: .utf8)`. On error → set `saveError = error.localizedDescription`.
     - Default filename: `"\(profile.name.lowercased().replacingOccurrences(of: " ", with: "-")).hosts"`.
     - On success → `showHUD("profile.detail.export.saved")`.
   - `private func showHUD(_ key: LocalizedStringKey)`:
     ```swift
     hudMessage = key
     Task { @MainActor in
         try? await Task.sleep(for: .milliseconds(1500))
         hudMessage = nil
     }
     ```

### 4. HUD overlay
4. [ ] In `ProfileDetailView` body, aggiungere `.overlay(alignment: .top)` con una piccola pillola material (system style):
   ```swift
   .overlay(alignment: .top) {
       if let hudMessage {
           Label(hudMessage, systemImage: "checkmark.circle.fill")
               .padding(.horizontal, 16)
               .padding(.vertical, 8)
               .background(.regularMaterial, in: Capsule())
               .foregroundStyle(.primary)
               .padding(.top, 12)
               .transition(.opacity.combined(with: .move(edge: .top)))
       }
   }
   .animation(.easeInOut(duration: 0.2), value: hudMessage != nil)
   ```
   Coerente con conventions (material nativo, no shadow custom, SF Symbol, font semantici).

### 5. Alert di errore
5. [ ] Aggiungere `.alert("profile.detail.export.save.error.title", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } }), presenting: saveError) { _ in Button("common.button.ok", role: .cancel) {} } message: { Text($0) }`.

### 6. Verifica
6. [ ] Build (xcodebuild) → BUILD SUCCEEDED.
7. [ ] Manual smoke check non eseguibile da CLI — segnalare nel changelog.

## Out of scope
- UTI custom `.hostsfile` (la task lo indica esplicitamente come out of scope).
- Export multi-profilo o dell'intero database.
- Export in formati alternativi (JSON, ecc.).
- Persistenza dell'ultima directory di salvataggio.
- Voce "Esporta" nel context menu della sidebar.

## Open questions
- Nessuna.

---

**Completed:** 2026-05-15

**Resolution:** Added `HostsFileManager.formatProfile(_:)` and an Export `Menu` in `ProfileDetailView` (Copy / Save to file…) with HUD success overlay and native alert on save failure. Disabled on read-only profiles. Strings localized. Build verified.
