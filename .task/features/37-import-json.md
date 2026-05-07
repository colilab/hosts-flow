# Task: Import — JSON con merge/replace

## Obiettivo

Importare un file JSON esportato (vedi 09-export-json) ripristinando profili e record, con scelta utente tra modalità "merge" o "replace".

## Requisiti

- File picker JSON
- Validazione schema (`version` field)
- Modalità:
  - **Merge:** profili esistenti preservati, importati con suffisso "(importato)" se duplicate name
  - **Replace:** elimina tutto, sostituisce con import
- Preview con count profili/record da importare

## Checklist

- [ ] Menu "File → Importa JSON..."
- [ ] `NSOpenPanel` `allowedContentTypes: [.json]`
- [ ] Decode `ExportPayload` con error handling (file corrotto / version unsupported)
- [ ] Sheet con preview + scelta merge/replace + bottone Importa
- [ ] Replace: alert conferma "Verranno eliminati N profili esistenti"
- [ ] On import: ricostruisci `Profile` + `HostRecord` con nuovi UUID (no clash con esistenti)
- [ ] Trigger `writeHosts` post-import

## Note tecniche

- Migration logica per `version` field: switch su versioni supportate
- Error UX: "File JSON non valido" / "Versione non supportata: X (max supportato: Y)"
