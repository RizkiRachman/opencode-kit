# Simplify — Code Simplification

**Reduce complexity without changing behavior.**

## When to Use

- Code is working but hard to understand
- Before refactoring or extending
- After implementing (cleanup pass)

## Principles

1. **Single Responsibility** — one function, one job
2. **Early Returns** — reduce nesting
3. **Extract Helpers** — break out repeated logic
4. **Remove Dead Code** — delete unused paths
5. **Name Things** — replace magic values

## Workflow

### 1. Read the Code
```bash
lean-ctx ctx_read --path "src/target.ts"
```

### 2. Identify Complexity
- Deep nesting (>3 levels)
- Long functions (>50 lines)
- Duplicated logic
- Magic numbers/strings

### 3. Simplify
- Extract helper functions
- Use early returns
- Replace conditionals with lookup tables
- Remove unnecessary abstractions

### 4. Verify
```bash
lean-ctx ctx_shell --command "npm test"
```

## Anti-Patterns

- ❌ Over-abstraction (premature optimization)
- ❌ Clever one-liners (readability > brevity)
- ❌ Removing comments that explain *why*
