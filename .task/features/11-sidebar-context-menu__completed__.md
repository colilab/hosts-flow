# Task: Sidebar — Context menu completo

## Obiettivo

Context menu sulla row profilo con: Rinomina, Duplica, Elimina, separatore, Attiva/Disattiva.

## Requisiti

- Menu nativo macOS (`.contextMenu`)
- Voce "Elimina" in rosso
- Duplica crea copia con suffisso "(copia)" e tutti i record duplicati
- Toggle voce dinamica ("Attiva" se inattivo, "Disattiva" se attivo)

## Checklist

- [ ] **Guard readonly**: se `profile.isReadOnly` → "Rinomina" e "Elimina" disabilitate, "Duplica" sempre disponibile, toggle attiva/disattiva sempre disponibile
- [ ] `.contextMenu` su ProfileRow
- [ ] Voce "Rinomina" → set `editingProfileID` (vedi 03-sidebar-rename-inline)
- [ ] Voce "Duplica" → `ProfileStore.duplicate(profile:)` (clona con record)
- [ ] Voce "Elimina" → trigger alert (vedi 03-sidebar-delete)
- [ ] Divider
- [ ] Voce toggle attiva/disattiva → `profile.isActive.toggle()` + `writeHosts`
- [ ] Implementare `ProfileStore.duplicate(profile:context:)` che copia profilo + record (nuovi UUID)

## Note tecniche

- Naming duplicato: se "Sviluppo" esiste già, prova "Sviluppo (copia)", poi "Sviluppo (copia 2)" ...
- I record duplicati devono avere nuovi `id` UUID

---

**Completed:** 2026-05-07

**Resolution:** Context menu esteso con Rinomina / Duplica / Elimina / divider / Attiva-Disattiva. Aggiunto `ProfileStore.duplicate(_:context:)` con naming unico "(copia)/(copia N)" e deep copy dei record. Guard readonly su Rinomina, Elimina, Toggle (Duplica sempre disponibile).
