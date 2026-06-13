# Rollback Protocol

**Purpose**: Define rollback strategies for failed executions in the opencode-kit orchestration contract, including partial rollback, full rollback, and state recovery.

## Rollback Overview

### When Rollback is Required
- Execution score < 50 (BLOCKED verdict)
- Code review finds critical/blocking issues
- Tests fail after execution
- Contract state becomes invalid
- Unrecoverable error during execution

### Rollback Levels
| Level | Scope | Trigger | Recovery Time |
|-------|-------|---------|---------------|
| L1 | Single file | Local test failure | < 1 minute |
| L2 | Multiple files | Integration failure | 1–5 minutes |
| L3 | Full feature | Architecture mismatch | 5–15 minutes |
| L4 | Complete session | Contract corruption | Human intervention |

## Git-Based Rollback

### Pre-Execution Snapshot
Before any execution phase:
```
lean-ctx_ctx_shell(command="git stash push -m 'opencode-kit-pre-execution-snapshot'")
```

### Rollback Commands by Level

#### L1: Single File Rollback
```
lean-ctx_ctx_shell(command="git checkout HEAD -- <file-path>")
```

#### L2: Multiple Files Rollback
```
lean-ctx_ctx_shell(command="git diff --name-only HEAD~1 | xargs git checkout HEAD --")
```

#### L3: Full Feature Rollback
```
lean-ctx_ctx_shell(command="git reset --hard HEAD~<commits-to-rollback>")
```

#### L4: Complete Session Rollback
```
lean-ctx_ctx_shell(command="git stash pop")
lean-ctx_ctx_shell(command="git reset --hard <pre-execution-commit>")
```

## State Rollback

### Contract State Recovery
```json
{
  "rollback_id": "<unique-id>",
  "timestamp": "<ISO 8601>",
  "rollback_level": "L1|L2|L3|L4",
  "trigger": "<what caused rollback>",
  "contract_state": {
    "current": "<state when rollback triggered>",
    "target": "<state to restore to>"
  },
  "files_affected": ["<list of files>"],
  "rollback_steps": [
    {
      "step": 1,
      "action": "<action>",
      "validation": "<how to verify>"
    }
  ]
}
```

### Memory System Rollback
1. **Contract**: Restore to last valid state from backup
2. **STATE.md**: Revert to last checkpoint
3. **GitNexus**: Re-index affected symbols
4. **Graphify**: Remove invalidated patterns
5. **Lean-ctx session**: Restore from snapshot

## Partial Rollback Strategy

### When Full Rollback is Costly
1. Identify the specific failing component
2. Rollback only that component
3. Preserve working components
4. Re-execute with adjusted approach

### Partial Rollback Checklist
- [ ] Identify failing component(s)
- [ ] Verify other components are stable
- [ ] Create rollback plan for failing component
- [ ] Execute partial rollback
- [ ] Validate partial rollback succeeded
- [ ] Resume execution from stable point

## Post-Rollback Actions

### After Rollback
1. **Update contract**: Record rollback event in metrics
2. **Log lessons**: Add to lessons_learned what caused failure
3. **Adjust approach**: Modify plan based on failure analysis
4. **Notify**: Inform orchestrator of rollback completion
5. **Re-assess**: Determine if retry is viable or escalate

### Rollback Metrics
```json
{
  "rollback_count": 0,
  "rollback_history": [
    {
      "timestamp": "<ISO 8601>",
      "level": "L1|L2|L3|L4",
      "trigger": "<cause>",
      "success": true,
      "recovery_time_ms": 0
    }
  ]
}
```

## Rollback Validation

### Before Resuming Execution
- [ ] Rollback completed successfully
- [ ] Contract state is valid
- [ ] All files are in expected state
- [ ] Tests pass (if applicable)
- [ ] No orphaned artifacts remain
- [ ] Metrics updated

### Rollback Failure
If rollback itself fails:
1. Log the rollback failure
2. Preserve current state as-is
3. Escalate to human with full context
4. Do NOT attempt further automated recovery