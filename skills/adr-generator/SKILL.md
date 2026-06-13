---
description: Auto-generate Architecture Decision Records when making architectural decisions. Logs to contract.json decisions.adr_log[].
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
lean-ctx ctx_shell(command="bash src/adr.sh --title \"...\" --context \"...\" --decision \"...\" --alternatives \"...\" --consequences \"...\"")
```

The CLI script handles ID assignment, duplicate detection, and contract injection automatically.
