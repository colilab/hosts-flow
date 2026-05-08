# CLAUDE.md

Host Flow — SwiftUI app for managing hosts inside `etc/hosts` with dynamic selection of user created profiles.

## ⚡ Quick Reference

| Command | Type | Use When |
|---------|------|----------|
| `/grill-me` | Skill | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. |
| `/task` | Skill | Generate a task plan directly from a user-provided prompt. Uses the grill-me skill to interview the user about the request, then writes a plan, awaits confirmation, executes, updates the changelog and marks completion. If after 3 grilling rounds the requirements are still insufficient, abort the plan. |

---

## Decision Protocol

When analysis reveals multiple valid implementation approaches, always stop and present the options clearly before writing any code. Wait for explicit confirmation of which approach to take. Never pick one unilaterally.

@architecture.md
@conventions.md
@brief.md
