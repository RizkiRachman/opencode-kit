# Agent Handoff Protocol

**Purpose**: Define the protocol for transferring work between agents, including state preservation, context transfer, and validation. Every handoff is governed by the contract state machine.

**Reference**: `rules/rules.json` → `state_machine.transitions[]`, `templates/contract.json`

---

## Handoff Overview

Agents transfer work via the contract state machine. Each handoff **MUST**:

1. Validate current state allows the transition
2. Preserve all context in contract and memory systems
3. Create a structured handoff pack
4. Validate the recipient agent can run in the new state
5. Persist everything before signaling completion

### Handoff Flow

```
┌─────────────┐     handoff pack     ┌─────────────┐
│ Source Agent│ ──────────────────▶  │Recipient    │
│ (complete)  │     (validated)      │ Agent       │
└──────┬──────┘                      └──────┬──────┘
       │                                    │
       ▼                                    ▼
  Update contract                      Load contract
  Persist memory                       Run pre-flight gate
  Record metrics                       Begin work
```

---

## Handoff Pack Structure

### Required Fields

```json
{
  "handoff_id": "<unique-id>",
  "timestamp": "<ISO 8601>",
  "from_agent": "<source agent>",
  "to_agent": "<target agent>",
  "contract_state": {
    "current": "<current state>",
    "target": "<target state>"
  },
  "context": {
    "objective": "<what we're trying to achieve>",
    "completed": ["<list of completed steps>"],
    "in_progress": ["<current work>"],
    "pending": ["<remaining work>"]
  },
  "artifacts": {
    "files_created": ["<list>"],
    "files_modified": ["<list>"],
    "decisions_made": ["<list>"],
    "open_questions": ["<list>"]
  },
  "scorecard": {
    "current_score": 0,
    "verdict": "INIT|PASS|RETRY|BLOCKED",
    "issues": []
  },
  "instructions": "<specific instructions for recipient>"
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `handoff_id` | Yes | Unique identifier (e.g. `handoff-20260613-001`) |
| `timestamp` | Yes | ISO 8601 timestamp of handoff event |
| `from_agent` | Yes | Source agent role name (e.g. `orchestrator`, `task-manager`) |
| `to_agent` | Yes | Recipient agent role name (e.g. `code-reviewer`, `scoring`) |
| `contract_state.current` | Yes | Current state from contract before transition |
| `contract_state.target` | Yes | Target state for the transition |
| `context.objective` | Yes | The high-level goal (copied from contract.requirements.goal) |
| `context.completed` | Yes | List of steps/items completed by source agent |
| `context.in_progress` | No | Work still in progress at time of handoff |
| `context.pending` | Yes | Work that still needs to be done |
| `artifacts.files_created` | No | Files created during this phase |
| `artifacts.files_modified` | No | Files modified during this phase |
| `artifacts.decisions_made` | No | Key decisions recorded during this phase |
| `artifacts.open_questions` | No | Questions that need resolution |
| `scorecard.current_score` | Yes | Current combined score (0-100) |
| `scorecard.verdict` | Yes | Current verdict: `INIT`, `PASS`, `RETRY`, or `BLOCKED` |
| `scorecard.issues` | No | Known issues to address |
| `instructions` | Yes | Specific, actionable instructions for the recipient agent |

---

## State Transitions

### Valid Handoff Paths

| From State | To State | Source Agent | Recipient Agent | Pre-condition | Post-condition |
|------------|----------|--------------|-----------------|---------------|----------------|
| `INIT` | `PLAN` | orchestrator | planner | Contract loaded, scope defined | Plan produced |
| `PLAN` | `PLAN_SCORED` | orchestrator (via scoring) | scoring | Plan complete, handoff pack ready | Score computed |
| `PLAN_SCORED` | `EXECUTE` | orchestrator | task-manager | Score ≥ 70, plan approved | Implementation done |
| `EXECUTE` | `EXECUTE_SCORED` | orchestrator (via scoring) | scoring | Execution complete, handoff pack ready | Score computed |
| `EXECUTE_SCORED` | `REVIEW` | orchestrator | code-reviewer | Score ≥ 70, code ready | Review completed |
| `REVIEW` | `REVIEW_SCORED` | orchestrator (via scoring) | scoring | Review complete, handoff pack ready | Score computed |
| `REVIEW_SCORED` | `COMPLETE` | orchestrator | learner | Score ≥ 70, all requirements met | Knowledge persisted |
| `*` | `BLOCKED` | any | escalation | Score < 50 or unrecoverable error | Escalated to user |
| `BLOCKED` | `INIT` | user | orchestrator | User intervention | Reset for retry |

### Transition Rules

1. Every state transition is a handoff event — even scoring transitions
2. The orchestrator drives all state transitions and handoffs between subagents
3. Subagents never transition state directly; they signal readiness via the handoff pack
4. Transitions requiring scoring always pass through the scoring pipeline first
5. The `BLOCKED` state can only be exited via user intervention

---

## Handoff Validation Checklist

Before finalizing any handoff, the source agent **MUST** verify:

- [ ] **Source agent completed its process steps** — all required work for this phase is done
- [ ] **Contract state is valid for transition** — the `from → to` pair exists in `rules.json state_machine.transitions[]`
- [ ] **Score meets threshold** — if the transition requires scoring, `scorecard.current_score ≥ 70`
- [ ] **Handoff pack contains all required fields** — `handoff_id`, `timestamp`, `from_agent`, `to_agent`, `contract_state`, `context.objective`, `context.completed`, `context.pending`, `scorecard.current_score`, `scorecard.verdict`, `instructions`
- [ ] **Recipient agent's pre-flight gate will pass** — contract loaded, state validated, branch not main
- [ ] **All artifacts are persisted to disk/memory** — files saved, contract written, knowledge stored
- [ ] **Metrics updated with handoff event** — `contract.metrics.handoff_failures`, `contract.metrics.agents_used`, elapsed time
- [ ] **No blocking issues remain unresolved** — `scorecard.issues` is empty or all non-blocking
- [ ] **Lean-ctx session saved** — `ctx_session action="save"` called to preserve conversation context

---

## Memory System Updates

### During Handoff, Update in Order

| Priority | System | Tool | Action |
|----------|--------|------|--------|
| 1 | **Lean-ctx knowledge** | `lean-ctx_ctx_knowledge` with `action="remember"` | Persist facts, decisions, and gotchas from this phase |
| 2 | **Lean-ctx session** | `lean-ctx_ctx_session` with `action="finding"` | Record key findings and decisions |
| 3 | **Contract (persistence)** | `lean-ctx_ctx_knowledge` with `action="remember"` and `key="orchestration-contract"` | Update state, session, outputs, metrics; persist updated contract JSON |
| 4 | **GitNexus** | `npx --yes gitnexus analyze` | Re-index code relationships if files were created/modified |
| 5 | **STATE.md** | `lean-ctx_ctx_read` then `lean-ctx_ctx_edit` | Append completed work, update current focus |
| 6 | **Graphify** | Auto-consumes from gitnexus | Verify via graphify stats (if available) |
| 7 | **Telemetry/metrics** | Update `contract.metrics` | Record handoff event: agent used, elapsed time, score |

### Update Procedure

```json
// Step 1: Persist facts
// lean-ctx_ctx_knowledge(action="remember", category="architecture", key="handoff.<task_id>", value="<handoff pack as JSON>")

// Step 2: Record findings
// lean-ctx_ctx_session(action="finding", value="Handoff: <from> → <to> completed for <task_id>")

// Step 3: Update contract
// lean-ctx_ctx_knowledge(action="remember", category="architecture", key="orchestration-contract", value="<updated contract JSON>")

// Step 4: Re-index code intelligence (if files changed)
// lean-ctx_ctx_shell(command="npx --yes gitnexus analyze")

// Step 5: Persist session
// lean-ctx_ctx_session(action="save")
```

---

## Scoring During Handoff

### When Scoring is Required

The scoring pipeline runs during handoffs at these transition points:

| Handoff | Scoring Required | Purpose |
|---------|-----------------|---------|
| Source → orchestrator | Yes (always) | Orchestrator must evaluate output before transitioning |
| orchestrator → scoring | No | Scoring IS the transition |
| scoring → orchestrator | No | Score is the handoff pack |
| orchestrator → next agent | No | Handoff pack IS the instruction |

### Scoring Pipeline (run by orchestrator)

```
1. Tier 1 (Rule Checks):  Start at 100, deduct per violation
   → lean-ctx_ctx_knowledge(action="recall", ...) to load rules
   → Check PREFLIGHT, IMPACT, WRITE, SCORE rules
   
2. Tier 2 (LLM Judge):    If score ≥ 70, run subtask with judge prompt
   → templates/judge-prompt.md
   
3. Verdict:               Map combined score to verdict
   → ≥ 70: PASS  → transition to target state
   → 50-69: RETRY → increment retry.attempt, re-run phase
   → < 50: BLOCKED → set state=BLOCKED, escalate
```

---

## Handoff Failure Handling

### If Handoff Fails

1. **Log failure** — Record in `contract.metrics.handoff_failures`:
   ```json
   {
     "failed_handoff": "<handoff_id>",
     "from": "<source>",
     "to": "<target>",
     "reason": "<description of failure>",
     "timestamp": "<ISO 8601>"
   }
   ```

2. **Preserve state** — Do **NOT** modify `contract.state` if handoff fails. Roll back any partial state changes.

3. **Retry once** — Attempt handoff again with corrected pack:
   - Fix validation issues
   - Complete missing fields
   - Resolve blocking issues

4. **Escalate** — If retry fails, set `contract.state = BLOCKED` and escalate per protocol:
   - Persist the failed handoff pack for debugging
   - Record in `contract.retry.issues[]`
   - Notify user with full context

### Stale Handoff Detection

| Condition | Action |
|-----------|--------|
| `contract.session.last_updated` > 30 minutes ago | **Warn**: Verify state is current, check for stale context |
| `contract.session.last_updated` > 60 minutes ago | **Assume stale**: Reload contract from disk, re-validate state |
| Contract file corrupted or unparseable | **Escalate**: Set `state=BLOCKED`, report corrupted contract |
| Handoff pack references non-existent handoff_id | **Reject**: Generate new handoff_id, do not reuse stale IDs |

### Recovery Procedures

```json
// Stale handoff recovery:
// 1. lean-ctx_ctx_read(path=".opencode/orchestration/contract.json") — reload from disk
// 2. Validate state against rules.json state_machine
// 3. If valid: continue with fresh handoff
// 4. If invalid: set state=BLOCKED, escalate

// Corrupted contract recovery:
// 1. lean-ctx_ctx_knowledge(action="recall", query="orchestration-contract") — try memory
// 2. If memory valid: restore from memory, persist to disk
// 3. If memory also corrupted: escalate to user
```

---

## Model Change During Handoff

When a model change occurs between agent handoffs:

1. **Record in handoff pack**: Add `model_changed: true`, `previous_model`, and `current_model` fields to the handoff pack JSON
2. **Context bridge**: The outgoing agent MUST write a model-context summary to `lean-ctx ctx_session finding` that includes:
   - What the previous model accomplished
   - What the new model needs to know
   - Any model-specific assumptions or patterns the previous model used
3. **State preservation**: Ensure `contract.json.outputs` contains all artifacts before handoff — the new model will rely on these, not in-memory context
4. **Scoring adjustment**: The scoring pipeline should note the model change in `metrics` so score comparisons across sessions account for model differences
5. **Validation**: The incoming agent's pre-flight should verify it has loaded the model-context summary before proceeding

---

## Agent-Specific Handoff Notes

### orchestrator → planner
- Handoff pack must include `scope.included`, `scope.excluded`, and `requirements.*` from contract
- Planner needs the full goal and acceptance criteria

### scoring → orchestrator
- Handoff pack is the score result — only `scorecard.*` and `issues[]` are required
- Score is authoritative; orchestrator must not override without re-scoring

### orchestrator → task-manager
- Handoff pack must include `decisions.approved_architecture` and `decisions.coding_standard`
- Task manager needs retry issues if this is a retry

### orchestrator → code-reviewer
- Handoff pack must include all `artifacts.files_created[]` and `artifacts.files_modified[]`
- Reviewer needs the original requirements and acceptance criteria

### orchestrator → learner
- Final handoff — must include ALL artifacts, decisions, scores, and metrics
- Learner needs complete session history for knowledge extraction

---

## Tool Usage Rules

All handoff operations **MUST** use lean-ctx tools. Direct shell execution (bash) is prohibited.

| Operation | Tool | Example |
|-----------|------|---------|
| Read contract from memory | `lean-ctx_ctx_knowledge` with `action="recall"` | `lean-ctx_ctx_knowledge(action="recall", query="orchestration-contract")` |
| Read contract from disk | `lean-ctx_ctx_read` | `lean-ctx_ctx_read(path=".opencode/orchestration/contract.json")` |
| Persist contract | `lean-ctx_ctx_knowledge` with `action="remember"` | `lean-ctx_ctx_knowledge(action="remember", category="architecture", key="orchestration-contract", value="<json>")` |
| Persist handoff pack | `lean-ctx_ctx_knowledge` with `action="remember"` | `lean-ctx_ctx_knowledge(action="remember", category="architecture", key="handoff.<task_id>", value="<json>")` |
| Record finding | `lean-ctx_ctx_session` with `action="finding"` | `lean-ctx_ctx_session(action="finding", value="Handoff: <from> → <to> completed")` |
| Save session | `lean-ctx_ctx_session` with `action="save"` | `lean-ctx_ctx_session(action="save")` |
| Re-index gitnexus | `lean-ctx_ctx_shell` | `lean-ctx_ctx_shell(command="npx --yes gitnexus analyze")` |
| Read handoff pack from memory | `lean-ctx_ctx_knowledge` with `action="recall"` | `lean-ctx_ctx_knowledge(action="recall", query="handoff.<task_id>")` |
