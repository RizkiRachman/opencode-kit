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

| Command | Description |
|---------|-------------|
| `bash .opencode/src/status.sh` | View contract state |
| `bash .opencode/src/diff.sh [branch1] [branch2]` | Compare across branches |
| `bash .opencode/src/adoption-check.sh` | Verify project adoption |
| `bash .opencode/src/contract-lock.sh acquire/release` | Contract locking |
| `bash .opencode/src/audit-trail.sh` | Audit trail management |
| `bash .opencode/src/scoring-pipeline.sh` | Run scoring pipeline |

## Enforcement Mechanisms

### State Machine Validation

The `preflight.sh` Check 6 validates contract state against `rules.json` transitions:

- Ensures the current state is known and valid transitions exist
- Prevents illegal state transitions before they occur
- Terminal states (`COMPLETE`, `BLOCKED`) have no outgoing transitions — once reached, no further work proceeds

This validation runs automatically before any contract operation, ensuring the state machine invariants are always respected.

### Contract Locking

The `contract-lock.sh` script provides file-based locking for concurrent agent access to the contract.

**Commands:** `acquire`, `release`, `check`, `force`

**Features:**
- Atomic writes via temp file + `mv` to prevent corruption
- 30-second retry timeout with exponential backoff
- 5-minute stale lock detection and cleanup

```sh
bash .opencode/src/contract-lock.sh acquire <agent_name>
# ... do work ...
bash .opencode/src/contract-lock.sh release
```

### Adoption Enforcement

The `adoption-check.sh` script verifies the project is properly initialized and all required artifacts exist.

**6 checks performed:**
1. `contract.json` — Contract file exists
2. `rules.json` — State machine rules exist
3. `agents/` — Agent configurations exist
4. `skills/` — Skill definitions exist
5. `opencode.json` — Project configuration exists
6. `src/` — Source scripts exist

```sh
bash .opencode/src/adoption-check.sh      # Check only
bash .opencode/src/adoption-check.sh --fix # Auto-repair via init
```

## Audit Trail

The `audit-trail.sh` script logs all contract events to a JSONL audit log for traceability and debugging.

**Commands:** `log`, `transition`, `scoring`, `violation`, `query`, `export`

**Event fields:** timestamp, agent, action, contract_state, git branch

```sh
# Log an event
bash .opencode/src/audit-trail.sh log <agent> <action> '<details_json>'

# Query events by type and date range
bash .opencode/src/audit-trail.sh query --type scoring --since 2026-06-01

# Export full audit log as JSON
bash .opencode/src/audit-trail.sh export --format json
```
