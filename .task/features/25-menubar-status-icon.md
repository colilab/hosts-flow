# Task: MenuBar — Icona dinamica

## Obiettivo

L'icona MenuBarExtra cambia in base allo stato dell'app: nessun profilo attivo, alcuni attivi, errore scrittura.

## Requisiti

- Icona base: SF Symbol `network`
- Stato 0 attivi: `network.slash` (grigio)
- Stato N attivi: `network` (filled o accent color)
- Stato errore: `network.badge.shield.half.filled` con tinta rossa
- Tooltip nativo con riassunto stato

## Checklist

- [ ] Computed `menuBarIconName: String` in app
- [ ] Computed `menuBarIconColor: Color?`
- [ ] Switch su:
  - `profileStore.hasWriteError` → errore
  - `profileStore.activeProfileCount == 0` → slash
  - else → normale
- [ ] `MenuBarExtra("Host Flow", systemImage: iconName)` reactive
- [ ] Tooltip: "Host Flow — N profili attivi" / "Host Flow — Errore scrittura /etc/hosts"

## Note tecniche

- `MenuBarExtra` non supporta `Color` su systemImage direttamente: usare `image:` con `Image(systemName:).foregroundStyle(color)` se serve colore custom
- Considerare `.symbolRenderingMode(.hierarchical)` per look macOS native
