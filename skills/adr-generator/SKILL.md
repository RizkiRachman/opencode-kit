---
description: Auto-generate Architecture Decision Records when making architectural decisions. Logs to contract.json decisions.adr_log[].
---

# ADR Generator

When making an architectural decision, record it in `contract.json` → `decisions.adr_log[]`.

## ADR Format

```json
{
  "id": "ADR-003",
  "date": "2026-06-11",
  "title": "Decision title",
  "context": "Why this decision was needed",
  "decision": "What was decided",
  "alternatives": "What was considered and rejected",
  "consequences": "Positive and negative effects"
}
```

## When to Record

- Any non-trivial architectural choice
- Any rejected approach that future agents might propose again
- Any convention or rule change
- When asked "is this decision recorded?"

## Auto-ID

- Read existing `adr_log[]` from contract
- Next ID = max ADR-NNN + 1
- If no existing log, start at ADR-001

## CLI Alternative

```sh
bash src/adr.sh --title "..." --context "..." --decision "..." --alternatives "..." --consequences "..."
```

The CLI script handles ID assignment, duplicate detection, and contract injection automatically.
