# Plan: DMG drag-to-Applications installer

**Date:** 2026-05-21
**Type:** chore

## Original prompt
> quando scarico il dmg creato su github releases non mi appare un auto installer o il solito shortcat dialog per trascinare l'app in Applications, ma mi apre solo una cartella contente la mia app. vorrei invece una procedura automatica o semiautomatica

## Summary
Sostituire la creazione del DMG in `Scripts/build-release.sh`: invece di `hdiutil create -srcfolder` (che produce un semplice volume con la sola .app), usare `create-dmg` (Homebrew) per generare un DMG con il classico layout drag-to-Applications — icona dell'app a sinistra, symlink a `/Applications` a destra, finestra dimensionata, nessun background custom. La firma Sparkle EdDSA viene già calcolata dopo la creazione del DMG, quindi resta valida automaticamente.

## Steps
1. [ ] In [Scripts/build-release.sh](Scripts/build-release.sh): aggiungere preflight check che `create-dmg` sia presente (`command -v create-dmg`); se manca, exit con messaggio esplicito `ERROR: create-dmg not found. Run: brew install create-dmg`.
2. [ ] Sostituire il blocco `hdiutil create -volname "Host Flow" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"` con una chiamata a `create-dmg` che:
   - usa `--volname "Host Flow"`
   - imposta `--window-size 540 380`
   - posiziona l'icona app con `--icon "HostFlow.app" 140 190`
   - aggiunge symlink Applications con `--app-drop-link 400 190`
   - usa `--icon-size 100`
   - usa `--format UDZO`
   - **non** passa `--background` (layout pulito, sfondo default)
   - **non** passa `--codesign` né `--notarize` (l'app è già ad-hoc signed da `sign-manifest.sh`; aggiungere codesign romperebbe il manifest hash)
   - **non** passa `--no-internet-enable` solo se necessario; usa flag default
3. [ ] Verificare che `create-dmg` non sovrascriva la firma del bundle: passa il `.app` come positional arg al tool, non un sorgente con contenuti aggiuntivi. Il commento esistente nel file che spiega "hdiutil only copies the bundle" va aggiornato per riflettere create-dmg (stesso principio: copy-only, no re-sign).
4. [ ] Aggiornare [docs/release.md](docs/release.md) (se esiste la sezione su build-release) con il nuovo prerequisito `brew install create-dmg`.
5. [ ] Aggiornare [README.md](README.md) sezione build/release se menziona la creazione del DMG.

## Out of scope
- PKG installer automatico (escluso esplicitamente).
- Background image custom nel DMG.
- Code signing Developer ID / notarization (l'app resta ad-hoc signed come oggi).
- Auto-install di `create-dmg` via brew (errore esplicito al suo posto).
- Modifiche al workflow GitHub Actions `release.yml` (la build viene fatta localmente prima del tag push, non in CI).

## Open questions
- Nessuna.

---

**Completed:** 2026-05-21

**Resolution:** `Scripts/build-release.sh` now stages the `.app` in a temp dir and invokes `create-dmg` with a 540×380 window, app icon at (140,190) and `/Applications` drop-link at (400,190), producing the classic drag-to-Applications DMG. Preflight check fails fast if `create-dmg` is missing. Docs updated.
