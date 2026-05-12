# Task: Settings — Info versione

## Obiettivo

Sezione "Info" in Settings con versione app, build number, link a sito/repo, copyright.

## Requisiti

- Versione da `CFBundleShortVersionString`
- Build da `CFBundleVersion`
- Link cliccabile a repo GitHub o sito (placeholder se non disponibile)
- Copyright "© 2026 Colilab"

## Checklist

- [x] `LabeledContent("Versione", value: "\(version) (\(build))")`
- [x] Helper `Bundle.main.appVersion` + `appBuild`
- [ ] Link "Sito web" / "Codice sorgente" (placeholder URL)
- [x] Copyright in footer della section
- [x] Verificare che `project.yml` abbia version + build settings corretti

## Note tecniche

- `Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String`
- `Link("...", destination: URL(string: "...")!)`
