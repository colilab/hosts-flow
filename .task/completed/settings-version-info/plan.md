# Plan: Settings — Info versione

**Date:** 2026-05-12
**Type:** feature

## Summary

Sezione "Info" in Settings con `LabeledContent` che mostra la versione applicativa (`CFBundleShortVersionString`) e footer con copyright "© 2026 Colilab". Versione e build esposte via helper `Bundle.main.appVersion` / `appBuild`. `project.yml` aggiornato con `MARKETING_VERSION` (semver `1.0.0`) e `CURRENT_PROJECT_VERSION` (`1`) come single source of truth, e `Info.plist` referenzia le variabili tramite `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`.

## Steps

1. [x] Aggiungere `MARKETING_VERSION: "1.0.0"` e `CURRENT_PROJECT_VERSION: "1"` in `project.yml` (settings.base) — `HostFlow/project.yml`
2. [x] Aggiornare `Info.plist`: `CFBundleShortVersionString` → `$(MARKETING_VERSION)`, `CFBundleVersion` → `$(CURRENT_PROJECT_VERSION)` — `HostFlow/Resources/Info.plist`
3. [x] Nuovo helper `Bundle.appVersion` + `Bundle.appBuild` — `HostFlow/Helpers/Bundle+AppInfo.swift`
4. [x] Sezione "Info" in `SettingsView` con `LabeledContent("Versione", value: Bundle.main.appVersion)` e footer `© 2026 Colilab` (caption, secondary) — `HostFlow/Views/Settings/SettingsView.swift`
5. [x] `xcodegen generate` + build verifica
6. [x] Verificata versione iniettata nell'`Info.plist` del bundle (`1.0.0` / `1`)

## Out of scope

- Link "Sito web" / "Codice sorgente" (placeholder URL) — escluso dall'utente per questa iterazione
- Mostrare il build number tra parentesi accanto alla versione — escluso esplicitamente

## Open questions

- Nessuna
