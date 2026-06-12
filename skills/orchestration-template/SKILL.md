---
description: MANDATORY — Load orchestration contract before any work. Validates state, branch, phase.
---

# Orchestration Template

**MANDATORY on EVERY task start.** Forces agent to load contract from lean-ctx BEFORE any work.

## Contract Protocol

1. **LOAD** — Run: `lean-ctx ctx_knowledge recall --query "orchestration-contract"`
   - If found: extract state, session, requirements, decisions, governance
   - If NOT found: check `.opencode/orchestration/contract.json` → create fresh

2. **VALIDATE** — Check state transition is legal per rules.json state_machine
   - If illegal: set state=BLOCKED, persist, STOP

3. **CHECK CONTRACT PERMISSIONS** — Extract `contract.governance.permissions.allowed_execution`
   - `allowed_execution.tools` defines which tool patterns agents may use for shell execution
   - Default: `["lean-ctx_*"]` — use `lean-ctx ctx_shell`, never `bash` or `snip`
   - `allowed_execution.denied` lists explicitly denied tools
   - Violating the whitelist triggers SHELL_002 (CRITICAL/BLOCK)

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
