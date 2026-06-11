---
description: Guidelines for efficient token usage — read strategically, batch operations, minimize context.
---

# Token Optimization

## Reading Strategy

- **Search before read**: use `gitnexus_query` or `grep` before reading files
- **Read sections, not whole files**: use `ctx_read(path, mode: "lines:N-M")`
- **Use `ctx_read` compression modes**: `map` for structure, `signatures` for signatures, `full` only when needed
- **Cache re-reads**: `ctx_read` is cached — subsequent reads of unchanged files cost ~13 tok

## Batching

- **Batch independent reads**: Use `ctx_multi_read` to read multiple files in one call
- **Batch independent writes**: Use `write` calls in parallel
- **Batch grep patterns**: Combine related patterns in a single grep call

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
