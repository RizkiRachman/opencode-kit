---
description: Score every subagent output after delegation. Tier 1 (rule checks) + Tier 2 (LLM judge) + verdict.
---

# Scoring Pipeline

After every subagent delegation returns, run three-tier scoring before proceeding.

## Tier 1 — Rule-Based Checks

Start at 100. Deduct for each violation:

| Check | Deduction |
|-------|:---------:|
| Schema valid (required fields present) | -15 |
| Permissions violated (forbidden patterns) | -40 |
| Blast radius unsafe (HIGH/CRITICAL) | -40 |
| Writing order wrong | -15 |
| Required fields missing | -15 |

If subtotal < 70 → skip Tier 2, use subtotal as combined score.

## Tier 2 — LLM Judge

Use prompt from `.opencode/rules/rules.json` → `scoring.tier2.judge_prompt`:

```
Score 0-100 on:
- Fulfills requirements? (0-40)
- Follows governance? (0-30)
- Completeness? (0-20)
- Edge cases covered? (0-10)
```

Return JSON: `{ "score": N, "rationale": "...", "missing_items": [...] }`

## Tier 3 — Verdict

| Score | Verdict | Action |
|:-----:|---------|--------|
| ≥ 70 | PASS | Advance to next phase |
| 50–69 | RETRY | Fix issues (if attempt < max) |
| < 50 | BLOCKED | Escalate to user |
