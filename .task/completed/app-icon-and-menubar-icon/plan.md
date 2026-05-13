# Task: App Icon + Menu Bar Icon

## Obiettivo

Sostituire il placeholder vuoto di `AppIcon` con il logo definitivo dell'app e introdurre un'icona custom per il `MenuBarExtra`, in sostituzione (o affiancamento) degli SF Symbols attualmente usati in [MenuBarView.swift:11](HostFlow/Views/MenuBar/MenuBarView.swift#L11).

L'utente fornirà gli asset grafici nei formati richiesti qui sotto.

## Stato attuale

- `AppIcon.appiconset` esiste ma contiene solo `Contents.json` senza PNG → in Finder/Dock l'app appare con icona generica.
- Menu bar usa 3 SF Symbols dinamici in base allo stato (`network`, `network.slash`, `network.badge.shield.half.filled`).

## Decisione da prendere prima di iniziare

L'icona menu bar ha **due strategie alternative**, da confermare con l'utente:

1. **Icona singola statica** — un solo glyph custom che sostituisce tutti e 3 gli stati. Lo stato (errore/attivo/inattivo) viene comunicato solo via colore + tooltip.
2. **Set di 3 icone custom** — un asset per ogni stato, sostituendo gli SF Symbols 1:1.

Default proposto: **strategia 2** per mantenere la chiarezza visiva attuale.
Se l'utente non ha asset per tutti gli stati, fallback alla strategia 1 con SF Symbols residui per gli stati non coperti.

---

## Asset richiesti — App Icon

### Formato

- **PNG**, sRGB, **senza canale alpha** (background opaco)
- Forma quadrata (macOS applica automaticamente la maschera squircle se l'icona è "full bleed"; in alternativa il design può già includere padding e angoli arrotondati nello stile macOS Big Sur+ — preferito)
- Nessuna ombra esterna nell'asset (macOS non la applica più; il design dovrebbe essere "flat squircle" stile HIG attuale)

### Sizes da fornire (10 file PNG)

Naming consigliato: `icon_<size>x<size>@<scale>x.png`

| File | Pixel reali | Idiom | Scale | Size logica |
|------|-------------|-------|-------|-------------|
| `icon_16x16@1x.png`    | 16×16     | mac | 1x | 16×16 |
| `icon_16x16@2x.png`    | 32×32     | mac | 2x | 16×16 |
| `icon_32x32@1x.png`    | 32×32     | mac | 1x | 32×32 |
| `icon_32x32@2x.png`    | 64×64     | mac | 2x | 32×32 |
| `icon_128x128@1x.png`  | 128×128   | mac | 1x | 128×128 |
| `icon_128x128@2x.png`  | 256×256   | mac | 2x | 128×128 |
| `icon_256x256@1x.png`  | 256×256   | mac | 1x | 256×256 |
| `icon_256x256@2x.png`  | 512×512   | mac | 2x | 256×256 |
| `icon_512x512@1x.png`  | 512×512   | mac | 1x | 512×512 |
| `icon_512x512@2x.png`  | 1024×1024 | mac | 2x | 512×512 |

### Variant dark / tinted — NON supportate via `.appiconset` su macOS

Verificato empiricamente con `actool` (Xcode 26.5, macOS SDK 26.5): nel formato `.appiconset`, le `appearances` con `luminosity: dark` o `luminosity: tinted` vengono **silenziosamente ignorate** dal compilatore quando `idiom: mac`. Nessun errore né warning, ma le entry non finiscono in `Assets.car`.

Differenze per piattaforma:
- **iOS / iPadOS 18+**: supportato in `.appiconset`
- **macOS 15+ (Sequoia)** tinted icons: richiedono il nuovo formato **`.icon`** prodotto da **Icon Composer** (tool standalone in Xcode 16+), incompatibile con `.appiconset`
- **macOS** dark variant: storicamente non esiste un asset separato — il design dell'icona deve avere contrasto sufficiente per essere leggibile in entrambi i mode (la nostra squircle chiara funziona già bene)

Decisione presa: **saltare entrambe le variant per macOS**. Se in futuro si vuole supportare il tinting di Sequoia, va aperto un task separato per la migrazione a Icon Composer.

### Destinazione

`HostFlow/Resources/Assets.xcassets/AppIcon.appiconset/`

`Contents.json` va aggiornato con i nomi file e — se ci sono variant — con i blocchi `appearances` (`luminosity: light/dark`) e `appearances` con `luminosity: tinted`.

---

## Asset richiesti — Menu Bar Icon

### Formato (preferito: PDF vettoriale)

- **PDF singolo file**, vettoriale, **template image** (Xcode lo configura via `Render As: Template Image` nell'Asset Catalog)
- Colore: **nero puro su sfondo trasparente**. macOS applica automaticamente il colore corretto (nero in light mode, bianco in dark mode, accent in stato attivo se richiesto via `.foregroundStyle`)
- Dimensione design: **18×18 pt** (l'altezza utile della status bar è ~22pt, l'icona ne occupa ~18pt per coerenza con SF Symbols `body` weight)
- Padding interno: ~1pt su ogni lato (l'asset finale deve respirare visivamente)
- Stroke weight: equivalente a SF Symbols `regular` (≈1.5pt a 18pt) per coerenza con il resto della barra

### Alternativa: Symbol Image (.svg da SF Symbols app)

Se si vuole avere un Symbol custom integrabile come fosse un SF Symbol:
- Esportare da app **SF Symbols** (template `network` come base)
- File `.svg` con i 9 layer richiesti (Ultralight → Black, Small/Medium/Large)
- Asset type: **Symbol Image Set** in Assets.xcassets

### Alternativa fallback: PNG @1x / @2x

Solo se PDF/SVG non è possibile:
- `menubar_icon.png` — 18×18 px
- `menubar_icon@2x.png` — 36×36 px
- Entrambi: nero puro, sfondo trasparente, template image

### Sizes per stato (se strategia 2 confermata)

Tre asset distinti, stesso formato:

| Stato | Naming consigliato | Sostituisce |
|-------|--------------------|-------------|
| Inattivo (nessun profilo attivo)        | `menubar_idle.pdf`  | `network.slash` |
| Attivo (≥1 profilo attivo)              | `menubar_active.pdf`| `network` |
| Errore scrittura `/etc/hosts`           | `menubar_error.pdf` | `network.badge.shield.half.filled` |

### Destinazione

`HostFlow/Resources/Assets.xcassets/` — un `Image Set` (o `Symbol Image Set`) per ciascun asset, con `Render As: Template Image`.

---

## Checklist implementativa

- [x] Confermare con utente strategia menu bar — scelta strategia 1 (icona singola statica)
- [x] Ricevere il master AppIcon 1024×1024 dall'utente
- [x] Generare le 10 size PNG con `sips` da master
- [x] Aggiornare `AppIcon.appiconset/Contents.json` con i `filename` corretti
- [x] **Bug fix collaterale:** aggiungere `CFBundleIconName = AppIcon` in `Info.plist` (mancava — senza questa chiave macOS non carica l'icona da `Assets.car`)
- [x] **Bug fix collaterale:** spostare `Assets.xcassets` da `resources:` (key inventata, ignorata silenziosamente da xcodegen) a `sources:` in `project.yml`
- [x] (Tentato) Variant dark + tinted — **non supportate** in `.appiconset` per macOS, vedi nota sotto. PNG tinted caricati e poi cancellati come orfani
- [x] Ricevere asset menu bar (SVG da SF Symbols app)
- [x] Creare `MenuBarIcon.symbolset` con `Contents.json` formato Symbol Image Set
- [x] Modificare `MenuBarLabel` in [MenuBarView.swift](HostFlow/Views/MenuBar/MenuBarView.swift): sostituire `Image(systemName: iconName)` con `Image("MenuBarIcon")`, rimossa funzione `iconName` (strategia 1 statica)
- [x] Verificare resa: Finder, About panel, status bar
- [x] Aggiornare `CHANGELOG.md`

## Esito finale

**App Icon:** ✅ funzionante, 21 entries in `Assets.car` (10 size × srgb/P3 + thumbnail).

**Menu Bar Icon:** ⚠️ funzionante visivamente ma **monochrome forzato** dal sistema. Vedi nota dedicata sotto.

## Limitazione macOS scoperta — colore custom symbol nella status bar

`NSStatusItem` (sotto a `MenuBarExtra`) forza il rendering monochrome con `controlTextColor` sui Symbol Image Set custom, ignorando `.foregroundStyle(_:)`. Per gli SF Symbols nativi questo non succede perché AppKit ha un percorso speciale di pre-rendering del colore in bitmap; per i custom symbols quel percorso non c'è.

Workaround tentato (poi revertito):
- `Color.mask { Image }` — produce un bitmap colorato ma rompe la geometria che `MenuBarExtra` si aspetta dalla label view (l'icona scompariva, restava solo un cerchio scuro al click)

Workaround disponibili ma non implementati (costo/benefit non giustificato):
- (a) Bypassare `MenuBarExtra` e gestire `NSStatusItem` direttamente in AppKit con `NSImage` pre-renderizzata per ogni stato
- (b) Ibrido: custom symbol per idle/active (monochrome), SF Symbol nativo solo per stato errore (dove il colore funziona)

Decisione presa: accettare il monochrome. Lo stato dei profili/errori è comunicato tramite tooltip al hover e via popover al click. Trade-off accettabile per mantenere il branding custom dell'icona.

## Note tecniche

- L'icona Dock viene aggiornata da Finder con un piccolo delay dopo prima build pulita; in caso di cache stale: `killall Dock` o reset di `~/Library/Caches/com.apple.iconservices.store`
- Le template image **ignorano** qualunque `.foregroundStyle(.red)` applicato come *fill*: il colore viene preso dal sistema. Per mantenere il colore rosso nello stato di errore, due opzioni:
  - (a) usare `.renderingMode(.original)` sull'asset errore (perdendo l'auto-adattamento light/dark)
  - (b) lasciare l'asset come template e applicare un overlay/badge separato di colore rosso
- Per lo stato "attivo" l'attuale `Color(nsColor: .controlAccentColor)` funziona solo con SF Symbol non-template; se si passa a template image va deciso se mantenere il colore di accent o lasciare la tinta nativa della status bar
- HIG menu bar: evitare icone troppo dettagliate, devono essere leggibili a 18×18pt — preferire glyph monolinea
- HIG app icon (Big Sur+): "flat squircle" con eventuale ombra/profondità interna ma **mai** ombra esterna; design centrato con respiro sui bordi
