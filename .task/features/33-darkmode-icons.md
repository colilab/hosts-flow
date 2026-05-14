# Task: AppIcon — Migrazione al formato `.icon` (Icon Composer)

## Obiettivo

Migrare `AppIcon` dal formato legacy `.appiconset` (PNG multi-size) al nuovo formato `.icon` di **Icon Composer** (Xcode 16+ / macOS 15+) per supportare nativamente le variant **light / dark / tinted**.

## Contesto

Verificato il 2026-05-13 e ri-confermato nell'audit dark-mode del 2026-05-14 (vedi CHANGELOG): il formato `.appiconset` su `idiom: mac` **ignora silenziosamente** le `appearances` con `luminosity: dark` o `tinted` — `actool` non le compila in `Assets.car` e non emette warning. L'unico path supportato da Apple per dark/tinted icons su macOS 15+ è il nuovo bundle `.icon` prodotto da Icon Composer.

L'icona attuale (`AppIcon.appiconset` con 10 PNG, master 1024×1024) funziona in entrambi i temi ma non offre la variant tinted né un trattamento dark dedicato.

## Requisiti

- **Tool**: Icon Composer.app (bundled con Xcode 16+)
- **Asset source**: master 1024×1024 attuale (`HostFlow/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`) come base, oppure SVG/Sketch/Figma se disponibile per qualità superiore
- **Output**: bundle `AppIcon.icon` che sostituisce `AppIcon.appiconset`
- **Compatibilità minima**: macOS 15 (Sequoia) per dark/tinted; fallback automatico al rendering light su macOS ≤ 14
- **Build system**: aggiornare `project.yml` se necessario (il bundle `.icon` è una directory, va inclusa come `sources:` analogamente a `.xcassets`)

## Variants da produrre

1. **Light** — design corrente (squircle chiara, soggetto scuro)
2. **Dark** — sfondo scuro, soggetto chiaro, contrasto pieno (HIG: "Dark variants should use a dark background and a light subject")
3. **Tinted** — monochrome (canale alpha + luminanza), il sistema applica la tinta basata su wallpaper/utente

## Checklist

- [ ] Aprire Icon Composer.app e creare nuovo documento `AppIcon.icon`
- [ ] Importare il master 1024×1024 attuale come livello base
- [ ] Configurare layer per Light (default)
- [ ] Configurare layer per Dark (sfondo scuro, soggetto invertito o ridisegnato)
- [ ] Configurare layer Tinted (monochrome, mask alpha)
- [ ] Esportare `AppIcon.icon` in `HostFlow/Resources/Assets.xcassets/` (sostituisce `AppIcon.appiconset`)
- [ ] Rimuovere `HostFlow/Resources/Assets.xcassets/AppIcon.appiconset/` (directory + 10 PNG + Contents.json)
- [ ] Verificare `project.yml`: il bundle `.icon` deve essere riconosciuto come asset (probabilmente già auto-detectato sotto `sources:`, come per `.xcassets`)
- [ ] Verificare `Info.plist`: `CFBundleIconName = AppIcon` resta invariato (il nome dell'asset non cambia, solo il formato)
- [ ] Rigenerare `xcodeproj` con `xcodegen` se necessario
- [ ] Build + verifica `Assets.car` con `actool` o `assetutil` — confermare che le variant siano compilate
- [ ] Verifica visiva in Finder + Dock + About panel:
  - [ ] System in Light mode → icona light
  - [ ] System in Dark mode → icona dark
  - [ ] System Settings → Appearance → Icon = Tinted → icona tinted con tinta utente

## Out of scope

- Design grafico dei layer dark/tinted: in questa task si usa il master attuale e si delega Icon Composer per le trasformazioni base. Un redesign completo della variant dark/tinted è una task separata se serve qualità superiore.
- MenuBarIcon: già un `.symbolset` template, adatta automaticamente — non interessato dalla migrazione.

## Note tecniche

- **Apple HIG**: <https://developer.apple.com/design/human-interface-guidelines/app-icons> — sezione "Dark and tinted variants"
- Il formato `.icon` è una directory bundle con `Assets.car`-like internals + manifest JSON; non va modificato a mano
- Se Icon Composer non è disponibile (Xcode < 16), questa task non può essere eseguita
- `actool` su Xcode 16+ riconosce automaticamente `.icon` bundles dentro `.xcassets` o anche standalone in resources

## Riferimenti

- Task audit dark-mode (precedente): `.task/completed/darkmode-audit/plan.md`
- Verifica empirica formato legacy: CHANGELOG entry del 2026-05-13, sezione "Limitazioni macOS scoperte e accettate", punto 1
