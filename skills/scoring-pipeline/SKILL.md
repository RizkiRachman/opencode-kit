---
description: Score every subagent output after delegation. Tier 1 (rule checks) + Tier 2 (LLM judge) + verdict.
---

## Tool Gateway (MANDATORY)

All file and shell operations MUST go through lean-ctx tools. NEVER use: bash, read, write, edit, grep, glob, github_*, postgres_*, firecrawl_*, context7_*, gitnexus_*, playwright_*, gh_grep_*, websearch_*, webfetch.

## MCP Gateway (MANDATORY)
ALL MCP calls MUST go through lean-ctx_ctx_shell using CLI tools:
| Service | CLI Command | Example |
|---------|-------------|---------|
| GitHub API | `gh` | `lean-ctx ctx_shell(command="gh pr list --repo owner/repo")` |
| GitNexus | `gitnexus` | `lean-ctx ctx_shell(command="gitnexus list")` |
| PostgreSQL | `psql` | `lean-ctx ctx_shell(command="psql -c 'SELECT 1'")` |
| Context7 | `npx @upstash/context7-mcp` | `lean-ctx ctx_shell(command="npx @upstash/context7-mcp --help")` |
| Firecrawl | `firecrawl` | `lean-ctx ctx_shell(command="firecrawl search 'query'")` |

NEVER call MCP tools directly (e.g., github_list_pull_requests, postgres_pg_health).

| Use this | Instead of |
|----------|-----------|
| lean-ctx_ctx_shell(command="...") | bash |
| lean-ctx_ctx_read(path="...") | read |
| lean-ctx_ctx_edit(path="...", old_string="...", new_string="...") | edit |
| lean-ctx_ctx_search(pattern="...", path="...") | grep |
| lean-ctx_ctx_tree(path="...") | ls |
| lean-ctx_ctx_multi_read(paths=[...]) | multiple reads |

**Why:** lean-ctx compresses output → 50-90% fewer tokens → cheaper + faster.
**Violation:** Using non-lean-ctx tools = CRITICAL violation = BLOCKED.

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
