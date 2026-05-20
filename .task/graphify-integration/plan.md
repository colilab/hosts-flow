# Plan: Integrazione graphify (knowledge graph della codebase)

**Date:** 2026-05-20
**Type:** chore
**Ref:** https://github.com/safishamsi/graphify

## Original prompt
> integra graphify su questa repo: https://github.com/safishamsi/graphify

## Summary
graphify è una CLI Python (`graphifyy` su PyPI) che trasforma la codebase in un knowledge graph
navigabile, integrandosi come skill di Claude Code. L'integrazione installa il tool, registra la
skill *dentro* la repo (versionata, come `task`/`grill-me`), installa l'hook git di rigenerazione
automatica e genera un grafo iniziale in modalità solo-codice (AST tree-sitter, nessun backend AID
esterno). Output e skill vengono versionati per renderli disponibili a chiunque cloni la repo.

## Steps
1. [ ] Installare `uv` via Homebrew — `brew install uv`
2. [ ] Installare graphify — `uv tool install graphifyy`
3. [ ] Verificare la CLI — `graphify --version` (atteso ≥ 0.8.13)
4. [ ] Registrare la skill per Claude Code — `graphify claude install`, poi rilocare la skill
       generata da `~/.claude/skills/graphify/` a `.claude/skills/graphify/` (versionata nella repo)
       e rimuovere la copia globale per evitare duplicati
5. [ ] Installare l'hook git di rigenerazione automatica — `graphify hook install`
       (post-commit, solo AST, nessun costo API) — `.git/hooks/post-commit`
6. [ ] Generare il grafo iniziale in modalità solo-codice via CLI (comando code-only ricavato da
       `graphify --help`) — output in `graphify-out/`
7. [ ] Aggiornare `.gitignore` — escludere `graphify-out/cache/` (cache locale non versionabile),
       mantenendo versionati `graph.html` / `graph.json` / `GRAPH_REPORT.md` / `obsidian/` / `wiki/`
8. [ ] Documentare l'integrazione in `README.md` — sezione con setup per i collaboratori
       (installare `uv` + `graphifyy`, eseguire `graphify hook install` dopo il clone, uso di `/graphify .`)
9. [ ] Aggiungere la riga `/graphify` alla Quick Reference di `.claude/CLAUDE.md`

## Out of scope
- Configurazione di un backend AI esterno (Gemini / OpenAI / Ollama) e relative API key
- Estrazione semantica dei file non-codice (Markdown/docs) — modalità solo-codice
- Integrazioni opzionali Neo4j e MCP server
- Funzionalità di PR analysis (`graphify prs`)
- Esecuzione di `git commit`: i file vengono creati e resi versionabili, ma il commit resta a carico dell'utente

## Open questions
- Comando CLI esatto per la build solo-codice del grafo (step 6): verrà determinato da
  `graphify --help` in fase di esecuzione — non blocca il piano.
