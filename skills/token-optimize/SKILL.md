---
description: Guidelines for efficient token usage — read strategically, batch operations, minimize context.
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

# Token Optimization

## Reading Strategy

- **Search before read**: use `lean-ctx ctx_shell(command="gitnexus query '...'")` or `lean-ctx ctx_search(pattern="...")` before reading files
- **Read sections, not whole files**: use `ctx_read(path, mode: "lines:N-M")`
- **Use `ctx_read` compression modes**: `map` for structure, `signatures` for signatures, `full` only when needed
- **Cache re-reads**: `ctx_read` is cached — subsequent reads of unchanged files cost ~13 tok

## Batching

- **Batch independent reads**: Use `ctx_multi_read` to read multiple files in one call
- **Batch independent writes**: Use `lean-ctx_ctx_edit` calls in parallel
- **Batch search patterns**: Combine related patterns in a single `lean-ctx_ctx_search` call

## Delegation

- **Delegate discovery to @explorer** — 2x faster, 1/2 cost for codebase search
- **Delegate docs to @librarian** — 10x better at finding API docs
- **Delegate bounded work to @fixer** — 2x faster, 1/2 cost for bounded edits
- **Delegate analysis to @observer** — isolates large binary files from context

## Anti-Patterns

- ❌ Reading full files you only need a snippet of
- ❌ Grep + read individual results instead of batch reading
- ❌ Keeping large context when only the summary is needed
- ❌ Re-reading the same file in multiple tool calls
