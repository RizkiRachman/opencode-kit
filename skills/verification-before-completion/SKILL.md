---
description: Run verification commands before claiming work is complete. Evidence before assertions.
---

# Verification Before Completion

**Never claim work is complete without running verification first.**

## Verification Order

For any code change, run in order:

### 1. Formatting
```bash
mvn spotless:apply  # or equivalent formatter
```

### 2. Compilation
```bash
mvn compile
# Expected: BUILD SUCCESS
```

### 3. Architecture (if ArchUnit present)
```bash
mvn test -Dtest="*Architecture*"
# Expected: all 7 ArchUnit rules pass
```

### 4. Unit Tests
```bash
mvn test
# Expected: 0 failures, 0 errors
```

### 5. Full Verification
```bash
mvn verify
# Expected: BUILD SUCCESS
```

### 6. Static Analysis (if configured)
```bash
# SpotBugs, PMD CPD, OWASP dependency check
```

## Evidence Rules

- ❌ "Tests should pass" → running isn't evidence
- ❌ "I didn't break anything" → verification is evidence
- ✅ Show the actual output for each command
- ✅ If a test fails, report the specific failure, don't bury it

## Checklist

- [ ] Formatting passes (spotless)
- [ ] Compiles without errors
- [ ] All tests pass (0 failures, 0 errors)
- [ ] No new warnings (or documented)
- [ ] `gitnexus_detect_changes()` confirms expected scope only
