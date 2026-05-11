# Plan: MenuBar — Icona dinamica

**Date:** 2026-05-11
**Type:** feature

## Original prompt
> # Task: MenuBar — Icona dinamica
>
> ## Obiettivo
> L'icona MenuBarExtra cambia in base allo stato dell'app: nessun profilo attivo, alcuni attivi, errore scrittura.
>
> ## Requisiti
> - Icona base: SF Symbol `network`
> - Stato 0 attivi: `network.slash` (grigio)
> - Stato N attivi: `network` (filled o accent color)
> - Stato errore: `network.badge.shield.half.filled` con tinta rossa
> - Tooltip nativo con riassunto stato
>
> ## Checklist
> - [ ] Computed `menuBarIconName: String` in app
> - [ ] Computed `menuBarIconColor: Color?`
> - [ ] Switch su:
>   - `profileStore.hasWriteError` → errore
>   - `profileStore.activeProfileCount == 0` → slash
>   - else → normale
> - [ ] `MenuBarExtra("Host Flow", systemImage: iconName)` reactive
> - [ ] Tooltip: "Host Flow — N profili attivi" / "Host Flow — Errore scrittura /etc/hosts"
>
> ## Note tecniche
> - `MenuBarExtra` non supporta `Color` su systemImage direttamente: usare `image:` con `Image(systemName:).foregroundStyle(color)` se serve colore custom
> - Considerare `.symbolRenderingMode(.hierarchical)` per look macOS native

## Summary
Aggiungere a `MenuBarExtra` un label custom reattivo che mostra un'icona variabile in base allo stato: errore di scrittura → `network.badge.shield.half.filled` rosso; 0 profili attivi → `network.slash` grigio (.secondary); N attivi → `network` filled con `.tint` accent. Tooltip nativo con descrizione coerente. Rendering hierarchical.

## Steps
1. [ ] Creare `MenuBarLabel` view in `HostFlow/Views/MenuBar/MenuBarView.swift`:
   - `@Query(filter: #Predicate<Profile> { $0.isActive && !$0.isReadOnly }) private var activeProfiles: [Profile]`
   - `@Environment(ProfileStore.self) private var store`
   - Body: `Image(systemName: iconName).symbolRenderingMode(.hierarchical).foregroundStyle(iconColor).help(tooltip)`
   - Computed `iconName`, `iconColor: Color`, `tooltip: String` con switch su `store.lastWriteError != nil`, `activeProfiles.isEmpty`, else.
2. [ ] In [HostFlowApp.swift](HostFlow/App/HostFlowApp.swift) sostituire `MenuBarExtra("Host Flow", systemImage: "network") { ... }` con la forma `MenuBarExtra { content } label: { MenuBarLabel() }` iniettando `modelContainer` e `environment(profileStore)` sul label (necessario perché il label vive fuori dal content).
3. [ ] Verifica build + smoke test:
   - Stato 0 attivi → slash grigio
   - Toggle 1 profilo → icona accent
   - Forza errore (helper non installato → `lastWriteError` valorizzato) → rosso

## Out of scope
- Badge numerico con conteggio profili
- Animazioni di transizione tra stati
- Persistenza dello stato errore oltre `lastWriteError` esistente

## Open questions
- Nessuna.

---

**Completed:** 2026-05-11

**Resolution:** Added `MenuBarLabel` with `@Query` on active profiles + observation of `ProfileStore.lastWriteError`; switched `MenuBarExtra` to `content:label:` form. Build OK.
