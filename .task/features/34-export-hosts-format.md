# Task: Export — Profilo come /etc/hosts text

## Obiettivo

Esportare il profilo selezionato come testo nel formato `/etc/hosts` (stesso output di `buildBlock` ma per singolo profilo, copiabile o salvabile su file).

## Requisiti

- Toolbar action "Esporta" nel `ProfileDetailView`
- Output: header `# <Profile Name>` + record (commentati se disabled)
- Due opzioni: "Copia negli appunti" e "Salva su file..."
- Save panel nativo macOS con default name `<profile>.hosts`

## Checklist

- [ ] Menu toolbar "Esporta" con submenu Copia / Salva su file
- [ ] `HostsFileManager.formatProfile(_ profile: Profile) -> String`
- [ ] Copia: `NSPasteboard.general.setString(...)`
- [ ] Salva: `NSSavePanel` con `allowedContentTypes: [.plainText]`
- [ ] Default filename: `\(profile.name.lowercased().replacingOccurrences(of: " ", with: "-")).hosts`

## Note tecniche

- `NSSavePanel` async con `.beginSheetModal(for:)` o sync `runModal()`
- Eventuale UTI custom `.hostsfile` (out of scope)
