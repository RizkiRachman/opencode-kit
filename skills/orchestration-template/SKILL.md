---
description: MANDATORY — Load orchestration contract before any work. Validates state, branch, phase.
---

## ⛔ MANDATORY GATEWAY: lean-ctx

**All initialization, configuration, and session operations MUST route through lean-ctx. No exceptions.**

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

# Orchestration Template

**MANDATORY on EVERY task start.** Forces agent to load contract from lean-ctx BEFORE any work.

## Contract Protocol

**MANDATORY GATEWAY: lean-ctx** — ALL steps below MUST use lean-ctx tools exclusively.

1. **LOAD** — Run: `lean-ctx ctx_knowledge recall --query "orchestration-contract"`
   - If found: extract state, session, requirements, decisions, governance
   - If NOT found: load from disk via `lean-ctx ctx_read(path=".opencode/orchestration/contract.json")`, then persist to lean-ctx
   - FAILURE TO LOAD = GOVERNANCE VIOLATION — STOP

2. **VALIDATE** — Check state transition is legal per rules.json state_machine
   - Read rules via `lean-ctx ctx_read(path=".opencode/rules/rules.json")`
   - If illegal: set state=BLOCKED, persist via lean-ctx, STOP

3. **CHECK CONTRACT PERMISSIONS** — Extract `contract.governance.permissions.allowed_execution`
   - `allowed_execution.tools` defines which tool patterns agents may use for shell execution
   - Default: `["lean-ctx_*"]` — use `lean-ctx ctx_shell`, never `bash` or `snip`
   - `allowed_execution.denied` lists explicitly denied tools
   - `allowed_execution.mandatory_gateway` MUST be `"lean-ctx"` — violating this triggers CRITICAL/BLOCK

4. **PERSIST** — After every delegation or phase change:
   ```
   lean-ctx ctx_knowledge remember \
     category architecture \
     key orchestration-contract \
     value "<updated JSON>"
   ```

## State Machine

```
INIT → PLAN → PLAN_SCORED → EXECUTE → EXECUTE_SCORED → REVIEW → REVIEW_SCORED → COMPLETE
                                                                                         ↘
BLOCKED (any phase) → user intervention → retry
```

**Transition Rules:**
- Each phase transition requires score ≥ 70 to proceed
- Score < 50 → BLOCKED
- Max 3 retry attempts

## Rules References
- `rules.json` — machine-readable enforcement rules
- `contract.json` — shared state contract
