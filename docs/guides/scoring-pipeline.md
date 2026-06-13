# Scoring Pipeline

Every subagent output is scored before the next phase begins.

## Tier 1 — Rule Checks

Automatic checks run by the orchestrator. Start at 100, deduct per violation:

| Check | Deduction |
|-------|:---------:|
| Schema valid (required fields present) | -15 |
| Permissions violated | -40 |
| Blast radius HIGH/CRITICAL | -40 |
| Writing order wrong | -15 |
| Fields missing | -15 |

If subtotal < 70 → skip Tier 2, use subtotal as combined score.

## Tier 2 — LLM Judge

If Tier 1 score ≥ 70, the orchestrator runs a judge via `subtask()`.

```json
{
  "score": 85,
  "rationale": "All requirements met. Writing order correct.",
  "missing_items": ["Test for null boundary case"]
}
```

**Dimensions:**
| Dimension | Max | What it evaluates |
|-----------|:---:|-------------------|
| Requirements | 40 | Does output satisfy goal + acceptance criteria? |
| Governance | 30 | Follows rules.json + writing order? |
| Completeness | 20 | All files created? Edge cases documented? |
| Edge cases | 10 | Nulls, errors, boundaries covered? |

## Tier 3 — Verdict

| Combined Score | Verdict | Action |
|:--------------:|:-------:|--------|
| ≥ 70 | **PASS** | Advance to next phase |
| 50–69 | **RETRY** | Increment retry count, re-delegate |
| < 50 | **BLOCKED** | Escalate to user |

## Configuration

Thresholds and deductions are in `rules.json` → `scoring`:

```json
{
  "scoring": {
    "tier1": { "schema_valid_deduction": 15, ... },
    "thresholds": { "pass": 70, "retry": 50, "max_attempts": 3 }
  }
}
```

Projects can override rule severity via `contract.json` → `validation.rule_overrides`.

## Implementation

The actual scoring pipeline is implemented as a 461-line Bash script at `src/scoring-pipeline.sh`. It executes Tier 1 rule-based scoring only (Tiers 2/3 are handled by the orchestrator in-process).

**Workflow:**

1. Reads `contract.json` and `rules.json` from the project
2. Applies 5 deduction checks configured in `rules.json` → `scoring.tier1`
3. Computes the final score, clamped to 0–100
4. Determines verdict: **PASS** (≥70), **RETRY** (50–69), **BLOCKED** (<50)
5. Writes results back into `contract.json` under:
   - `score.rules` — the Tier 1 numeric score
   - `score.combined` — the effective combined score (Tier 1 alone when < 70, or blended with LLM judge score)
   - `score.verdict` — one of `"PASS"`, `"RETRY"`, `"BLOCKED"`
6. On **BLOCKED** verdict: sets `contract.state = "BLOCKED"`
7. On **RETRY** or **BLOCKED** verdict: increments `retry.attempt` by 1
8. Exit codes: `0` = PASS, `2` = RETRY, `3` = BLOCKED

## CLI Usage

```sh
# Run scoring pipeline (uses defaults: .opencode/orchestration/contract.json, rules/rules.json)
bash .opencode/src/scoring-pipeline.sh

# With explicit paths
bash .opencode/src/scoring-pipeline.sh --contract .opencode/orchestration/contract.json --rules rules/rules.json

# Output to JSON file (writes scoring result without modifying contract.json)
bash .opencode/src/scoring-pipeline.sh --output .opencode/scoring-result.json
```

## Integration

The scoring pipeline fits into a broader automation chain:

- **Postflight hook** — `scoring-pipeline.sh` is called by `postflight.sh` after every agent delegation completes. This ensures every subagent output is scored before the next phase begins.
- **Contract locking** — `contract-lock.sh` protects concurrent access to `contract.json`. Scoring acquires an exclusive lock before reading/writing and releases it afterwards.
- **Audit trail** — `audit-trail.sh` logs every scoring event including the raw score, verdict, deductions applied, and timestamp. The audit log is append-only for traceability.
- **Adoption gate** — `adoption-check.sh` must pass (proving the contract was adopted by the next agent) before scoring runs. If adoption fails, scoring is skipped and the contract is flagged for review.
