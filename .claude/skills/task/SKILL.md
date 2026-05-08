---
name: task
description: Generate a task plan directly from a user-provided prompt. Uses the grill-me skill to interview the user about the request, then writes a plan, awaits confirmation, executes, updates the changelog and marks completion. If after 3 grilling rounds the requirements are still insufficient, abort the plan. TRIGGER when the user invokes /task with an inline prompt describing what to do (feature, bugfix, refactor, chore).
---

# /task — Task Resolution Workflow (prompt-based)

Resolve a task described inline by the user (no markdown task file required) following a grill → plan → confirm → execute → changelog flow.

## Usage

```
/task <prompt describing what to do>
```

Examples:
- `/task add a copy-to-clipboard button to the document detail page`
- `/task fix the login redirect loop when the Keycloak token expires`

---

## Workflow

### Step 1 — Ask for the slug

Right after receiving the initial prompt, ask the user:

> Vuoi fornire uno slug per questa task o devo generarlo automaticamente dal prompt?

Wait for the answer.
- If the user provides a slug, normalize it to kebab-case (lowercase, alphanumeric + dashes).
- If the user asks for auto-generation, derive a kebab-case slug from the prompt (≤ 60 chars).

The slug determines the working folder: `.task/<slug>/`. Create it if it does not exist.

### Step 2 — Collect attachments

If the user's prompt references attachments (uploaded files, pasted images, linked local paths, URLs to local resources), copy/move each one into `.task/<slug>/` preserving the original filename (sanitize if needed). Reference them by relative path in the plan.

External URLs (http/https) are not downloaded — keep them as links in the plan.

### Step 3 — Grill the user (max 3 rounds)

Invoke the **grill-me** skill to interview the user about the request. Walk down the decision tree one question at a time, exploring the codebase whenever a question can be answered there instead of asking.

Track the number of grilling rounds (a round = one batch of clarifying questions sent to the user, then their reply).

**Hard stop at 3 rounds.** If after 3 rounds the requirements are still ambiguous, contradictory, or insufficient to write a concrete plan, **abort**:

> ❌ Task aborted — after 3 rounds of clarification the requirements are still insufficient. Please rephrase the request or provide more detail before invoking `/task` again.

Do NOT write a plan file, do NOT touch application code.

Identify during grilling:
- **Type:** feature | bugfix | refactor | chore
- **Scope:** which modules / files are likely involved
- **Acceptance criteria:** what "done" looks like
- **Out of scope:** what is explicitly excluded
- **Ref:** ask the user if there is a Jira/external link (optional)

### Step 4 — Create Plan

Write the plan to `.task/<slug>/plan.md` using this template:

```markdown
# Plan: <title>

**Date:** <YYYY-MM-DD>
**Type:** <feature|bugfix|refactor|chore>
**Ref:** <link>          ← only if provided during grilling

## Original prompt
> <verbatim user prompt>

## Summary
<2-3 sentence description of what will be done and why>

## Steps
1. [ ] <step description> — `path/to/file.ts`
2. [ ] <step description>
...

## Attachments
- `<filename>` — <short description>          ← omit section if none

## Out of scope
- <anything explicitly NOT being done>

## Open questions
- <ideally none — anything still unresolved>
```

After writing the file, show the plan content in chat and say:

> Plan saved to `.task/<slug>/plan.md`. Review it, edit the file directly if needed, then reply **ok** to proceed — or describe changes you want.

**Do not write any application code yet. Wait for explicit confirmation.**

### Step 5 — Execute

Only proceed after the user replies **ok** (or equivalent confirmation).

Re-read the plan file before starting (the user may have edited it).

Execute each step in order. Mark steps complete as you go. Follow all project conventions from `CLAUDE.md`.

### Step 6 — Update Changelog

After all steps are complete, append an entry to `.task/CHANGELOG.md`. **Always write changelog entries in English**, regardless of the language used in the conversation.

```markdown
## [<YYYY-MM-DD>] — <short title>

**Type:** <type>
**Ref:** <link>          ← only include this line if a Ref was captured

### Changes
- <bullet per meaningful change>

### Files modified
- `path/to/file.ts` — <what changed>
```

### Step 7 — Mark plan as completed


Append a completion footer to `plan.md`:

```markdown
---

**Completed:** <YYYY-MM-DD>

**Resolution:** <one-line summary of how it was resolved>
```

move .task/<slug>/ in .task/completed/<slug>/ 

```
.task/<slug>/  →  .task/completed/<slug>/
```
delete .task/<slug>/

Then report completion to the user.
