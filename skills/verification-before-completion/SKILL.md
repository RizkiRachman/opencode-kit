---
description: Run verification commands before claiming work is complete. Evidence before assertions.
---

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
- [ ] `gitnexus_detect_changes()` confirms expected scope only
