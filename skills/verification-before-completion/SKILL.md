---
description: Run verification commands before claiming work is complete. Evidence before assertions.
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

# Verification Before Completion

**Never claim work is complete without running verification first.**

## Verification Order

For any code change, run in order:

### 1. Formatting
```bash
# Format code (e.g., spotless, prettier, black, gofmt)
```
Expected: zero files changed after formatting (idempotent).

### 2. Compilation
```bash
# Build/tests — check for compilation errors
# e.g., mvn compile, npm run build, cargo check, go build ./...
```
Expected: BUILD SUCCESS.

### 3. Architecture Rules (if applicable)
```bash
# Architecture tests — e.g., ArchUnit, layered boundary checks
```
Expected: all architecture rules pass.

### 4. Unit Tests
```bash
# Run unit tests — e.g., mvn test, npm test, pytest, cargo test
```
Expected: 0 failures, 0 errors.

### 5. Full Verification
```bash
# Full suite — e.g., mvn verify, npm test -- --all
```
Expected: BUILD SUCCESS.

### 6. Static Analysis (if configured)
```bash
# Linting, security scan, duplicate detection
# e.g., SpotBugs, ESLint, Clippy, bandit
```

## Evidence Rules

- ❌ "Tests should pass" → running isn't evidence
- ❌ "I didn't break anything" → verification is evidence
- ✅ Show the actual output for each command
- ✅ If a test fails, report the specific failure, don't bury it

## Checklist

- [ ] Formatting passes (idempotent)
- [ ] Compiles without errors
- [ ] All tests pass (0 failures, 0 errors)
- [ ] No new warnings (or documented)
- [ ] `lean-ctx ctx_shell(command="gitnexus detect-changes")` confirms expected scope only
