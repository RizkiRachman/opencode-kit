# Enforcement Architecture

opencode-kit enforces workflow adherence through 6 layered mechanisms. Each layer catches violations that earlier layers miss, creating defense-in-depth.

## Tool Usage: lean-ctx vs bash

opencode-kit enforces a strict tool boundary between agents and operators:

| Who | Tool | Why |
|-----|------|-----|
| **Agents** (all 10) | `lean-ctx_*` tools only | Context persistence, audit trail, contract locking, state machine compliance |
| **Operators** (manual) | `bash` scripts directly | Enforce, inspect, repair, debug the system |

**Agents MUST NOT use bash.** The `opencode.json` configuration sets `bash: false` and `lean-ctx_*: true` for every agent. Rules `TOOL_001` and `TOOL_002` in `rules.json` enforce this — violations are BLOCKED.

**Operators run enforcement scripts via bash** when they need to:
- Initialize or update a project (`init.sh`, `update.sh`)
- Check project health (`doctor.sh`, `adoption-check.sh`)
- Inspect contract state (`status.sh`, `diff.sh`)
- Force scoring or audit queries (`scoring-pipeline.sh`, `audit-trail.sh`)
- Release stale locks (`contract-lock.sh force`)
- Debug issues (`preflight.sh`, `verify.sh`)

This separation ensures agents operate within controlled boundaries while operators retain full system access for maintenance and oversight.

## The 7 Layers

```
┌─────────────────────────────────────────────────────┐
│  Layer 7: Checkpoint System                          │
│  Snapshot + validate at every step, auto-fix broken  │
├─────────────────────────────────────────────────────┤
│  Layer 6: Agent Templates                            │
│  Pre-flight gates in all 10 agent .md files          │
├─────────────────────────────────────────────────────┤
│  Layer 5: Audit Trail                                │
│  JSONL compliance logging for every event            │
├─────────────────────────────────────────────────────┤
│  Layer 4: Scoring Pipeline                           │
│  Tier 1 rule checks → Tier 2 LLM judge → Verdict    │
├─────────────────────────────────────────────────────┤
│  Layer 3: Contract Locking                           │
│  File locking prevents concurrent contract writes    │
├─────────────────────────────────────────────────────┤
│  Layer 2: Pre-flight Gate                            │
│  State machine, schema validation, br, rules    │
├─────────────────────────────────────────────────────┤
│  Layer 1: Adoption Check                             │
│  Verifies project is initialized before any work     │
└─────────────────────────────────────────────────────┘
```

## Layer 1: Adoption Check

**Script**: `src/adoption-check.sh`
**When**: Before any agent work begins
**What**: Verifies the project has been initialized with opencode-kit

### Checks
1. `contract.json` exists in `.opencode/orchestration/`
2. `rules.json` exists in `.opencode/rules/`
3. `agents/` directory exists with agent templates
4. `skills/` directory exists
5. `opencode.json` has opencode-kit plugin configured
6. `src/` directory exists with enforcement scripts

### Usage (Operator — run via bash)
```sh
# Check adoption status
bash .opencode/src/adoption-check.sh

# Auto-fix missing components
bash .opencode/src/adoption-check.sh --fix
```

### Failure Behavior
- Exit code 1: Adoption checks failed
- Exit code 0: All checks passed
- `--fix` mode runs `init.sh` to repair missing components

> **Note:** Agents do not call this directly. The orchestrator runs this as part of pre-flight, but the actual execution is via `lean-ctx ctx_shell` which wraps the bash script.

## Layer 2: Pre-flight Gate

**Script**: `src/preflight.sh`
**When**: Every agent invocation
**What**: Validates contract state, branch, rules compliance, and state machine transitions

### Checks
1. Contract exists and is valid JSON
2. Not on protected branch (main/master)
3. Contract state matches agent role
4. No CRITICAL rule violations
5. State machine transition is valid

### State Machine Validation (Check 6)
```sh
# Validates current state exists in rules.json transitions
# Validates a valid transition path exists from current state
# Terminal states (COMPLETE, BLOCKED) have no outgoing transitions
```

> **Agent access:** Agents run preflight via `lean-ctx ctx_shell` which wraps `preflight.sh`. Direct bash is blocked for agents.

### Failure Behavior
- CRITICAL violations → BLOCK agent
- HIGH violations → FLAG to orchestrator
- Invalid state → BLOCK with err msg
- Contract validation errors → BLOCK (agents cannot run)

### Contract Schema Validation (Check 8)

**Script**: `src/contract-lint.sh`
**When**: Before any agent work — integrated into preflight.sh Check 8 and doctor.sh
**What**: Validates contract.json structure, types, and required fields against the orchestration contract specification

**10 validation checks:**

| # | Check | What it validates | Blocks on |
|---|-------|-------------------|-----------|
| 1 | Required top-level fields | state, session, scope, requirements, governance, validation, outputs, score, retry, metrics | Missing fields |
| 2 | State enum | state must be one of 9 valid states | Invalid state string |
| 3 | Session fields | task_id, branch, created_at, model exist | Missing session data |
| 4 | Requirements | goal is non-empty, constraints is object not array | Missing goal, wrong type |
| 5 | Governance | active_agent exists, mode is valid enum | Invalid mode |
| 6 | Score | verdict is valid enum, combined is 0-100 | Invalid verdict |
| 7 | Retry | attempt is non-negative int, max_attempts is positive int | Invalid retry config |
| 8 | Outputs | code_changes and agent_reports are arrays | Wrong types |
| 9 | Metrics | cost_tokens is int, agents_used is array | Wrong types |
| 10 | Required tools | bash cannot be both blocked+required, lean-ctx_* must be required | Config conflict |

**Usage:**
```bash
# Validate contract (default: finds .opencode/orchestration/contract.json)
bash src/contract-lint.sh

# Strict mode (warnings also cause non-zero exit)
bash src/contract-lint.sh --strict

# JSON output for CI pipelines
bash src/contract-lint.sh --json

# Explicit contract path
bash src/contract-lint.sh --contract .opencode/orchestration/contract.json
```

**Exit codes:**
- `0` = PASS — all checks passed
- `1` = ERRORS — contract has structural errors (blocks agents)
- `2` = WARNINGS — contract has warnings (advisory, blocks in --strict mode)
- `3` = NO_CONTRACT — contract.json not found

**How it protects against broken overrides:**

When a downstream project (e.g., `goods-price-service`) overrides `contract.json` with invalid structure:
1. `contract-lint.sh` detects missing fields, wrong types, invalid enums
2. `doctor.sh` calls `contract-lint.sh` and reports individual errors
3. `preflight.sh` Check 8 runs `contract-lint.sh --strict` and BLOCKS if errors found
4. Agents never run with a broken contract — the enforcement chain stops them

## Layer 3: Contract Locking

**Script**: `src/contract-lock.sh`
**When**: During contract modifications
**What**: Prevents concurrent writes to contract.json

### Features
- **Atomic writes**: temp file + `mv` (atomic on same filesystem)
- **Lock format**: `PID|timestamp|agent_name`
- **Timeout**: 30 seconds with 1-second polling
- **Stale detection**: auto-clears locks older than 5 minutes

### Usage (Operator — run via bash)
```sh
# Acquire lock before modifying contract
bash .opencode/src/contract-lock.sh acquire orchestrator

# ... modify contract.json ...

# Release lock when done
bash .opencode/src/contract-lock.sh release

# Check lock status
bash .opencode/src/contract-lock.sh check

# Force release stale lock
bash .opencode/src/contract-lock.sh force
```

> **Agent access:** Agents acquire/release locks via `lean-ctx ctx_shell` which wraps `contract-lock.sh`. Direct bash is blocked for agents.

### Failure Behavior
- Lock timeout → error message, agent must retry
- Stale lock → auto-cleared on next acquire attempt

## Layer 4: Scoring Pipeline

**Script**: `src/scoring-pipeline.sh`
**When**: After each agent delegation
**What**: Scores agent output and determines verdict

### Tier 1 — Rule Checks
Automatic deductions from 100:

| Check | Deduction |
|-------|:---------:|
| Schema valid (required fields present) | -15 |
| Permissions violated | -40 |
| Blast radius HIGH/CRITICAL | -40 |
| Writing order wrong | -15 |
| Fields missing | -15 |

### Tier 2 — LLM Judge
If Tier 1 score ≥ 70, runs judge via `subtask()`:
- Requirements fulfillment (40 pts)
- Governance compliance (30 pts)
- Completeness (20 pts)
- Edge cases & risks (10 pts)

### Verdicts
| Score | Verdict | Action |
|:-----:|:-------:|--------|
| ≥ 70 | **PASS** | Advance to next phase |
| 50–69 | **RETRY** | Increment retry, re-delegate |
| < 50 | **BLOCKED** | Escalate to user |

### Usage (Operator — run via bash)
```sh
# Run scoring pipeline
bash .opencode/src/scoring-pipeline.sh

# With explicit paths
bash .opencode/src/scoring-pipeline.sh --contract .opencode/orchestration/contract.json --rules rules/rules.json

# Output to JSON
bash .opencode/src/scoring-pipeline.sh --output .opencode/scoring-result.json
```

> **Agent access:** Agents trigger scoring via `lean-ctx ctx_shell` which wraps `scoring-pipeline.sh`. Direct bash is blocked for agents.

### Exit Codes
- `0` = PASS
- `2` = RETRY
- `3` = BLOCKED

## Layer 5: Audit Trail

**Script**: `src/audit-trail.sh`
**When**: Every contract event
**What**: Logs all actions as JSONL for compliance and debugging

### Event Types
| Type | Description |
|------|-------------|
| `log` | Generic audit event |
| `transition` | State machine transition |
| `scoring` | Scoring result |
| `violation` | Rule violation |

### Event Format
```json
{
  "timestamp": "2026-06-13T10:30:00Z",
  "event_type": "scoring",
  "agent": "orchestrator",
  "action": "score_task_manager",
  "details": {"score": 85, "verdict": "PASS"},
  "contract_state": "EXECUTE",
  "git_branch": "feature/auth"
}
```

### Usage (Operator — run via bash)
```sh
# Log an event
bash .opencode/src/audit-trail.sh log <agent> <action> '<details_json>'

# Log a state transition
bash .opencode/src/audit-trail.sh transition <from_state> <to_state>

# Log a scoring event
bash .opencode/src/audit-trail.sh scoring <score> <verdict>

# Log a violation
bash .opencode/src/audit-trail.sh violation <rule_id> <message>

# Query events
bash .opencode/src/audit-trail.sh query --type scoring --since 2026-06-01

# Export as JSON
bash .opencode/src/audit-trail.sh export --format json
```

> **Agent access:** Agents log events via `lean-ctx ctx_shell` which wraps `audit-trail.sh`. Direct bash is blocked for agents.

### Storage
- Location: `.opencode/audit/audit.log`
- Format: JSONL (append-only)
- Each entry includes: timestamp, event_type, agent, action, details, contract_state, git_branch

## Layer 6: Agent Templates

**Location**: `templates/agents/*.md`
**When**: Every agent invocation
**What**: Pre-flight gates in all 10 agent templates enforce contract loading

### Template Pattern
Every agent template follows this structure:

```yaml
---
description: Agent purpose
mode: subagent
temperature: 0.3
permission:
  read: allow
  edit: deny  # or allow for implementation agents
  lean-ctx_*: allow
---
```

### Pre-flight Gate
All agents MUST execute this before any work:

```markdown
## Pre-flight Gate (MANDATORY)

1. Load contract: `lean-ctx ctx_knowledge recall orchestration-contract`
2. Validate state: Must be correct phase for this agent
3. Check branch: Must not be on main/master
4. Read rules: `lean-ctx ctx_read .opencode/rules/rules.json`
5. If ANY check fails → STOP, report to orchestrator
```

### Available Agents
| Agent | Role | Mode |
|-------|------|------|
| orchestrator | Primary coordinator | subagent |
| planner | Read-only planner | subagent |
| task-manager | Implementation executor | subagent |
| code-reviewer | Quality reviewer | subagent |
| learner | Post-execution learning | subagent |
| explorer | Codebase search specialist | subagent |
| librarian | Library docs researcher | subagent |
| architect | Strategic advisor | subagent |
| observer | System state monitor | subagent |
| fixer | Fast implementation specialist | subagent |

## Integration Flow

```
User sets goal in contract.json
         │
         ▼
┌─────────────────┐
│  Adoption Check  │ ← Layer 1: Verify project initialized
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Pre-flight Gate │ ← Layer 2: Validate state, br, rules, schema
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Checkpoint Save │ ← Layer 7: Snapshot + validate, auto-fix if needed
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Contract Lock   │ ← Layer 3: Prevent concurrent writes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Agent Work      │ ← Layer 6: Agent template enforces pre-flight
└────────┬────────┘      (lean-ctx_* tools only — bash BLOCKED)
         │
         ▼
┌─────────────────┐
│  Checkpoint Save │ ← Layer 7: Post-step snapshot + validate
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Scoring         │ ← Layer 4: Score output, determine verdict
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Audit Trail     │ ← Layer 5: Log all events
└────────┬────────┘
         │
         ▼
    Next Phase or BLOCKED
```

### Layer 7: Checkpoint System

**Script**: `src/checkpoint.sh`
**When**: Every workflow step (start and end)
**What**: Snapshots contract + git state, validates with lint + doctor, enables resume from last valid checkpoint

### Purpose
Checkpoints ensure:
1. **Resume capability** — if session breaks, load last valid checkpoint and continue
2. **Policy enforcement** — each checkpoint runs contract-lint + doctor checks automatically
3. **Audit trail** — full history of every state change with validation status
4. **Auto-fix** — if validation fails, contract syncs with template automatically

### Commands
| Command | What it does |
|---------|-------------|
| `save` | Snapshot contract + git, run lint + doctor, store checkpoint |
| `fix` | Sync contract with template (remove extra fields, add missing, fix types) |
| `validate` | Re-run lint + doctor, compare with stored checkpoint |
| `list` | Show all checkpoints with state, agent, validation status |
| `restore <id>` | Roll back contract to a specific checkpoint |
| `latest` | Show latest checkpoint details |
| `cleanup` | Remove old checkpoints, keep last 10 |

### Usage (Operator — run via bash)
```bash
# Save checkpoint
bash .opencode/src/checkpoint.sh save --agent orchestrator --step plan --summary "Plan phase"

# Save with auto-fix (fixes contract if validation fails)
bash .opencode/src/checkpoint.sh save --agent orchestrator --step build --fix

# Fix contract without saving checkpoint
bash .opencode/src/checkpoint.sh fix

# View checkpoint history
bash .opencode/src/checkpoint.sh list

# Restore from checkpoint
bash .opencode/src/checkpoint.sh restore checkpoint-20260613-143022
```

### Usage (Agent — via lean-ctx)
```
lean-ctx ctx_shell(command="bash .opencode/src/checkpoint.sh save --agent orchestrator --step plan --summary 'Plan complete'")
lean-ctx ctx_shell(command="bash .opencode/src/checkpoint.sh fix")
lean-ctx ctx_shell(command="bash .opencode/src/checkpoint.sh restore <id>")
```

### Checkpoint JSON Schema
```json
{
  "id": "checkpoint-20260613-143022",
  "timestamp": "2026-06-13T14:30:22Z",
  "state": "EXECUTE",
  "agent": "task-manager",
  "step": "build",
  "contract_snapshot": { "...full contract.json..." },
  "git": { "branch": "feature/x", "commit": "abc123", "dirty": true },
  "validation": { "lint_passed": true, "doctor_passed": true, "issues": [] },
  "context_summary": "Built 3 files, 2 tests passing"
}
```

### Auto-Fix Behavior
When `--fix` is used or `fix` command runs:
1. Load template contract from `.opencode/templates/contract.json`
2. Compare with current contract
3. **Remove** extra fields not in template
4. **Add** missing fields from template (preserving current values)
5. **Fix** type mismatches (e.g., string→list, dict→wrong-type)
6. Re-validate with lint + doctor
7. Report changes: `+N added, -N removed, ~N type-fixed`

### Failure Behavior
- Checkpoint save with lint FAIL → exit code 2, checkpoint saved with `validation.lint_passed=false`
- Checkpoint save with `--fix` and lint FAIL → auto-fix, re-validate, re-save
- Restore to invalid checkpoint → warns but still restores (user may need manual fix)

## Operator vs Agent Boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│                     OPERATOR (bash)                              │
│  init.sh  doctor.sh  status.sh  diff.sh  adoption-check.sh     │
│  scoring-pipeline.sh  contract-lock.sh  audit-trail.sh          │
│  preflight.sh  verify.sh  postflight.sh  update.sh              │
│  checkpoint.sh                                                   │
├─────────────────────────────────────────────────────────────────┤
│                     AGENTS (lean-ctx_*)                          │
│  ctx_read → ctx_write → ctx_shell → ctx_knowledge               │
│  ctx_search → ctx_multi_read → ctx_edit → ctx_tree              │
│  ctx_session → ctx_graph (if available)                          │
└─────────────────────────────────────────────────────────────────┘

Agents access enforcement via lean-ctx_* tools:
  lean-ctx ctx_shell   → wraps bash scripts (e.g., preflight.sh)
  lean-ctx ctx_read    → reads contract.json, rules.json
  lean-ctx ctx_knowledge → persists contract state, lessons learned
  lean-ctx ctx_write   → updates contract.json atomically
```

> **Why this matters:** bash bypasses the audit trail, context persistence, and contract locking that lean-ctx provides. If an agent uses bash directly, it breaks the enforcement chain. This is why `TOOL_001` blocks bash for agents — it's not a preference, it's a safety mechanism.

## Troubleshooting

See [Troubleshooting Guide](troubleshooting.md) for common issues with enforcement scripts.

## Related Documentation

- [Contract Protocol](contract-protocol.md) — Contract state machine and fields
- [Scoring Pipeline](scoring-pipeline.md) — Scoring tiers and verdicts
- [Troubleshooting](troubleshooting.md) — Common issues and solutions
