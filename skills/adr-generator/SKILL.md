---
name: adr-generator
description: Auto-generate Architecture Decision Records and session summaries for context continuity.
---

# ADR Generator — Architecture Decision Records + Session Summaries

**MANDATORY:** All file operations through lean-ctx tools.

## When to Use

- Making an architectural decision
- Completing a phase or session
- Recording what was done and what's next
- When asked "is this decision recorded?"

## File-Based ADRs

ADRs live in `adr/` folder at project root. Each ADR is a markdown file.

### Creating an ADR

1. Find next ID: read `adr/` folder, find highest NNN in `ADR-NNN-*.md`
2. Copy template from `adr/TEMPLATE.md`
3. Fill in: title, context, decision, alternatives, consequences
4. Save as `adr/ADR-NNN-title-slug.md`
5. Update `contract.json` -> `decisions.adr_index.files[]`

```bash
# Find next ADR number
ls adr/ADR-*.md 2>/dev/null | sort | tail -1 | grep -o "ADR-[0-9]*" || echo "ADR-001"
```

## Session Summaries

At the end of each session/phase, create a session summary in `adr/`.

### When to Generate

- After any code change
- Before session ends or agent hands off
- On orchestrator phase transition
- When user says "summarize" or "save progress"

### How to Generate

1. Read current contract.json for context
2. Read `adr/SESSION-TEMPLATE.md`
3. Fill in: goal, status, files changed, decisions, next steps, gotchas
4. Save as `adr/SESSION-YYYY-MM-DD-HHMM.md`
5. Update `contract.json` -> `decisions.session_summary`:
   - `last_generated`: ISO timestamp
   - `file`: path to session file
   - `context_ready`: true

### Session Summary Fields

| Field | Purpose |
|-------|---------|
| **goal** | What the user asked |
| **status** | Complete / Partial / Blocked |
| **files_changed** | What files were modified |
| **key_decisions** | Choices made and why |
| **context_for_next_session** | Most critical — what's left, patterns, gotchas |
| **lessons_learned** | What to do differently next time |

## How Next Session Uses It

When starting a new session:
1. Read `contract.json` -> `decisions.session_summary`
2. If `context_ready` is true and `last_generated` is recent (< 24h):
   - Read the session file
   - Check `context_for_next_session` for continuation context
   - Check `gotchas` to avoid repeated mistakes
   - Check `what_left_todo` for immediate next steps
3. This eliminates "what were we doing?" between sessions