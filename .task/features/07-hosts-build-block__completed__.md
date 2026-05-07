# Task: /etc/hosts — Build blocco da profili attivi

## Obiettivo

Generare il testo del blocco `/etc/hosts` da una lista di `Profile` attivi, includendo solo profili con `isActive = true` e tutti i loro record (enabled = riga normale, disabled = commentata).

## Requisiti

- Header warning subito dopo `# --- Host Flow Start ---`:
  ```
  # DO NOT EDIT MANUALLY — managed by Host Flow.app
  # Changes inside this block will be overwritten on the next sync.
  ```
- Header per ogni profilo: `# --- <Profile Name> ---`
- Record disabilitato → `# <ip> <hostname>`
- Record abilitato → `<ip> <hostname>`
- Profili inattivi completamente esclusi (no header)
- Output sandwiched tra marker start/end

## Checklist

- [ ] `HostsFileManager.buildBlock(profiles: [Profile]) -> String`
- [ ] Filter `isActive == true` + sort by `order`
- [ ] Subito dopo lo start marker: 2 righe warning "DO NOT EDIT MANUALLY"
- [ ] Per ogni profilo: header + record formattati
- [ ] Wrap con `# --- Host Flow Start ---\n<warning>\n...\n# --- Host Flow End ---`
- [ ] Test: 2 profili attivi (1 inattivo) → output corretto
- [ ] Test: profilo senza record → solo header
- [ ] Test: 0 profili attivi → blocco con solo marker

## Note tecniche

- Allineamento IP-hostname: tab o spazio singolo (preferire spazio per compatibilità tool)
- Linebreak: `\n` (Unix)

---

**Completed:** 2026-05-07

**Resolution:** `buildBlock` ora emette warning header (2 righe) dopo lo start marker, ogni profilo attivo preceduto da `# --- <Name> ---`, ordinamento deterministico per `order`, separatore IP/hostname spazio singolo (era tab).
