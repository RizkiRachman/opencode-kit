---
desc: Escalation protocol for BLOCKED state recovery and handoff in the opencode-kit orchestration contract.
---

# Escalation Protocol

## BLOCKED State Recovery

### When BLOCKED Occurs

The orchestrator contract (`contract.json`) sets `state=BLOCKED` when any of the following conditions are met:

| Condition | Threshold | Source |
|-----------|-----------|--------|
| Score < 50 on any gate | `escalation_threshold: 50` | `contract.json.validation.retry` |
| Score < 70 after max retries | `max_attempts: 3` after `score_threshold: 70` fails | `contract.json.validation.retry` |
| Contract state machine violation | Illegal transition detected by pre-flight gate | `rules.json §state_machine` |
| Tool unavailability (lean-ctx, gitnexus, graphify) | Fallback failed or no fallback exists | `contract.json.governance.permissions` |
| Resource exhaustion | Step limit reached, context window full | Runtime |
| Unrecoverable error in execution | Fatal error with no valid retry path | Runtime |

### Recovery Steps

1. **Identify Blocker**: Document the specific reason for BLOCKED state using `lean-ctx_ctx_knowledge` with action=`remember` and key=`blocker-reason`.
2. **Capture Context**: Save current contract state, error details, and partial progress to `contract.json.validation` and `contract.json.lessons_learned`.
3. **Escalation Path**:

   - **Level 1 — Automated Retry**: Retry with adjusted parameters. Max 2 retries. Increment `contract.json.validation.retry.attempt`. If attempt ≤ `max_attempts` and score ≥ `escalation_threshold`, reset to previous valid state and retry.
   - **Level 2 — Orchestrator Escalation**: Escalate to orchestrator for human review. Set `contract.json.decisions.prev_blockers` and flag for human attention.
   - **Level 3 — Human Intervention**: Request human intervention with full context pack. Archive session, create handoff.

4. **State Recovery**:

   - If retryable: Reset to previous valid state via `lean-ctx_ctx_session` action=`restore`, adjust approach, re-run pre-flight gate.
   - If not retryable: Archive session via `lean-ctx_ctx_session` action=`snapshot`, create handoff pack for human.

### Escalation Triggers

| Trigger | Level | Action |
|---------|-------|--------|
| Score < 50 (first occurrence) | L1 | Retry with different approach. Increment `contract.json.validation.retry.attempt`. |
| Score < 50 (second occurrence) | L2 | Escalate to orchestrator. Set `prev_blockers[]`. Persist contract. |
| Tool failure (first occurrence) | L1 | Try fallback tool from `contract.json.governance.permissions`, then escalate. |
| Tool failure (second occurrence) | L2 | Escalate to orchestrator. Log unavailable tool in `lessons_learned[]`. |
| Contract corruption | L3 | Human intervention required. Archive session. |
| Resource exhaustion (steps) | L2 | Summarize progress via `lean-ctx_ctx_session` action=`snapshot`. Create handoff pack. |
| Resource exhaustion (context) | L2 | Compress context via `lean-ctx_ctx_read` mode=`aggressive`. Continue or handoff. |
| Validation failure on recovery | L2 | Log failure in `contract.json.validation`. Reset and retry or escalate. |

### BLOCKED Recovery Template

```json
{
  "blocked_reason": "<specific reason for BLOCKED state>",
  "blocked_at": "<ISO 8601 timestamp>",
  "contract_state": "<state value from contract.json.state when blocked>",
  "attempted_retries": 0,
  "max_retries": 2,
  "escalation_level": 1,
  "context_pack": {
    "error_details": "<error message or stack trace>",
    "partial_progress": "<summary of what was accomplished before block>",
    "next_steps": "<recommended actions for recovery>",
    "files_affected": ["<list of file paths affected by partial work>"]
  }
}
```

### State Recovery Rules

1. **Never skip validation**: Recovery must pass the pre-flight gate before any action. Load contract, validate state transition, check permissions.
2. **Preserve audit trail**: All recovery attempts must be logged in `contract.json.metrics` and `contract.json.lessons_learned[]`. Use `lean-ctx_ctx_knowledge` action=`remember` with category=`audit`.
3. **Minimum viable recovery**: Restore to last known good state. Use `lean-ctx_ctx_session` action=`restore` on the most recent valid snapshot. Discard partial work from the failed attempt.
4. **Handoff on exhaustion**: After max retries, create handoff pack via `lean-ctx_ctx_session` action=`snapshot` with descriptive session_id. Summarize blocker, attempted fixes, and recommended next steps in the handoff.

### Resource Exhaustion Handling

- **Step limit reached**: Summarize progress using `lean-ctx_ctx_session` action=`task` with current completion status. Create handoff pack with partial work captured.
- **Context window full**: Compress context via `lean-ctx_ctx_read` mode=`aggressive` on low-priority files. Continue if compression yields sufficient headroom, otherwise handoff.
- **Tool unavailable**: Log unavailability via `lean-ctx_ctx_knowledge` action=`remember` with key=`tool-unavailable`. Use fallback tool if defined in `contract.json.governance.permissions`. If no fallback exists, escalate to L2.

### Handoff Pack Contents

When a session cannot proceed and must be handed off to a human or another session, the handoff pack must include:

1. **Session snapshot**: Via `lean-ctx_ctx_session` action=`snapshot` — captures full session state.
2. **Blocker summary**: Written to `lean-ctx_ctx_knowledge` with key=`handoff-blocker` — one-paragraph description of what went wrong.
3. **Recovery attempts**: List of retries attempted, parameters used, and outcomes.
4. **Partial artifacts**: Any files created or modified during the session, listed in `contract_pack.context_pack.files_affected[]`.
5. **Recommended next steps**: Concrete suggestions for how to proceed past the BLOCKED state.

### Contract State Machine Integration

The escalation protocol integrates with the contract state machine defined in `rules.json`:

```
INIT → PLANNING → BUILDING → REVIEWING → VERIFYING → COMPLETE
  ↓         ↓          ↓          ↓           ↓
BLOCKED ←──┴──────────┴──────────┴───────────┘
```

- Any phase can transition to `BLOCKED` on gate failure.
- From `BLOCKED`, the only legal transitions are back to the originating phase (after successful recovery) or to `COMPLETE` (if human intervenes and resolves).
- All transitions must be validated via the pre-flight gate before proceeding.

### Pre-Flight Gate for Recovery

Before executing any recovery action, the pre-flight gate MUST be run:

1. **Load contract**: `lean-ctx_ctx_knowledge` recall — query "orchestration-contract"
2. **Validate state**: Extract `contract.json.state`. Check that transition from `BLOCKED` is legal.
3. **Validate permissions**: Check `contract.json.governance.permissions.allowed_exec` — only use matching tools.
4. **Check recovery budget**: Verify `contract.json.validation.retry.attempt < contract.json.validation.retry.max_attempts`.
5. **Load rules**: Read applicable rules for escalation handling.

If any gate check fails, escalate immediately to L3 — do not attempt recovery.
