# Task: Import — File /etc/hosts → nuovo profilo

## Obiettivo

Importare un file in formato `/etc/hosts` come nuovo profilo, parsando le righe (commentate = disabled, normali = enabled).

## Requisiti

- File picker nativo (`NSOpenPanel`)
- Parser tollerante: ignora linee vuote, header `# Host Flow Start/End`, righe non parsabili
- Nuovo profilo creato con nome dal filename (senza estensione)
- Profilo importato `isActive = false` di default
- Anteprima record da importare prima di confermare

## Checklist

- [ ] Menu "File → Importa..." con file picker
- [ ] `NSOpenPanel` `allowedContentTypes: [.plainText]`
- [ ] Parser `HostsFileParser.parse(_ content: String) -> [HostRecord]`
  - skip empty + comment-only lines (eccetto record commentati con pattern `# IP HOSTNAME`)
  - regex match: `^(#?\s*)?(\S+)\s+(\S+)(\s+#.*)?$`
- [ ] Sheet anteprima: tabella record + bottoni Annulla/Importa
- [ ] On import: crea Profile + record + persist
- [ ] Errori: "Nessun record valido trovato" se parser non trova niente

## Note tecniche

- Parser deve riconoscere record disabled: `# 127.0.0.1 example.local`
- Ignorare hostname multipli sulla stessa riga (es. `127.0.0.1 a.local b.local`) o creare 2 record? → creare N record, uno per hostname
