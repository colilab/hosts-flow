# /task — Task Resolution Workflow

Resolve a task defined in a markdown file following a structured plan → confirm → execute → changelog flow.

## Usage

```
/task <path>
```

`<path>` is relative to the project root. Examples:
- `/task .task/feature/my-feature.md`
- `/task .task/bugfix/login-fix.md`

---

## Workflow

### Step 1 — Read & Analyse

Read the task file and any referenced attachments (look for paths under `.task/attachments/`).

Identify:
- **Type:** feature | bugfix | refactor | chore
- **Scope:** which modules / files are likely involved
- **Ambiguities:** anything unclear that would block planning
- **Ref:** look for a line starting with `Ref:` in the task file — this is the Jira/external link (e.g. `Ref: https://euronovate.atlassian.net/browse/WSG-2567`)

If ambiguities exist, ask the user targeted questions (one round only — batch all questions together). Wait for answers before proceeding.
If the process takes more than 10 minutes abort the task

### Step 2 — Create Plan

Derive a slug from the task filename (e.g. `my-feature.md` → `my-feature`).

Write the plan to `.task/plans/<slug>.plan.md` using this template:

```markdown
# Plan: <title>

**Date:** <YYYY-MM-DD>
**Type:** <feature|bugfix|refactor|chore>

## Summary
<2-3 sentence description of what will be done and why>

## Steps
1. [ ] <step description> — `path/to/file.ts`
2. [ ] <step description>
...

## Out of scope
- <anything explicitly NOT being done>

## Open questions
- <any remaining unknowns — ideally none>
```

After writing the file, show the plan content in chat and say:

> Plan saved to `.task/plans/<slug>.plan.md`. Review it, edit the file directly if needed, then reply **ok** to proceed — or describe changes you want.

**Do not write any application code yet. Wait for explicit confirmation.**

### Step 3 — Execute

Only proceed after the user replies **ok** (or equivalent confirmation).

Re-read the plan file before starting (the user may have edited it).

Execute each step in order. Mark steps complete as you go. Follow all project conventions from `CLAUDE.md`.

### Step 4 — Update Changelog

After all steps are complete, append an entry to `.task/CHANGELOG.md`. **Always write changelog entries in English**, regardless of the language used in the task file or conversation.

```markdown
## [<YYYY-MM-DD>] — <short title>

**Type:** <type>
**Ref:** <link>          ← only include this line if a Ref: was found in the task file

### Changes
- <bullet per meaningful change>

### Files modified
- `path/to/file.ts` — <what changed>
```

### Step 5 — Mark task as completed

Rename the task file by adding `__completed__` before the `.md` extension:

```
.task/<type>/<filename>.md  →  .task/<type>/<filename>__completed__.md
```

To rename: create the new file with the original content, append a completion footer, then delete the original:

```markdown
---

**Completed:** <YYYY-MM-DD>

**Resolution:** <one-line summary of how it was resolved>
```

Then report completion to the user.
