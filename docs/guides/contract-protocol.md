# Contract Protocol

The orchestrator contract (`contract.json`) is the single source of truth for every agent session.

## What it does

- Tracks **state** — what phase the workflow is in (INIT → PLAN → ... → COMPLETE)
- Stores **requirements** — the goal, acceptance criteria, and constraints
- Logs **decisions** — Architecture Decision Records (ADRs)
- Records **scores** — quality metrics from the scoring pipeline
- Captures **telemetry** — elapsed time, phases completed, agents used

## State Machine

```
INIT → PLAN → PLAN_SCORED → EXECUTE → EXECUTE_SCORED → REVIEW → REVIEW_SCORED → COMPLETE
                                                                                         ↘
                                      BLOCKED (any phase) → user intervention → retry
```

**Transition rules:**
- Each phase transition requires score ≥ 70
- Score < 50 → BLOCKED
- Max 3 retry attempts before escalation

## Key Fields

```json
{
  "state": "INIT",
  "contract_version": "0.5.8",
  "requirements": {
    "goal": "What we're building",
    "acceptance_criteria": ["testable condition 1"],
    "constraints": ["must not..."]
  },
  "governance": {
    "active_agent": "orchestrator",
    "current_guidance": "Instructions for this session",
    "extension_skills": ["java-conventions"],
    "permissions": { "do": [], "dont": ["push to main"] }
  },
  "decisions": {
    "adr_log": [
      { "id": "ADR-001", "date": "2026-06-11", "title": "Use contract protocol", ... }
    ]
  },
  "score": {
    "combined": 85,
    "verdict": "PASS"
  },
  "metrics": {
    "phases_completed": ["INIT", "PLAN", "PLAN_SCORED"]
  }
}
```

## Resolution Order

1. `.opencode/orchestration/contract.json` — project override
2. `~/.config/opencode-kit/contract.json` — global defaults
3. Plugin `templates/contract.json` — shipped defaults

## CLI

View contract state: `bash .opencode/src/status.sh`
Compare across branches: `bash .opencode/src/diff.sh [branch1] [branch2]`
