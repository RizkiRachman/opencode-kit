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
