# Task: Dark Mode — AppIcon dark variant

## Obiettivo

Aggiungere la variant dark di `AppIcon` in `Assets.xcassets` per coerenza con macOS Sonoma+ (icone tinted/dark).

## Requisiti

- Variant: light, dark, tinted (macOS 14+)
- Tutte le size standard: 16, 32, 128, 256, 512, 1024 @1x e @2x
- File design source: `.sketch` / `.figma` / SVG (out of scope qui)

## Checklist

- [ ] Aggiornare `AppIcon.appiconset/Contents.json` per supportare appearance variants
- [ ] Inserire PNG light per ogni size (placeholder accettabile per ora)
- [ ] Inserire PNG dark per ogni size
- [ ] Inserire PNG tinted (monochrome)
- [ ] Verificare in Finder + Dock (light/dark mode)
- [ ] Verificare in About panel (Settings → About)

## Note tecniche

- Apple HIG: dark icon background scuro, soggetto chiaro
- Tinted: monochrome, sistema applica tinta basata su wallpaper
- Placeholder accettabile finché non c'è asset finale
