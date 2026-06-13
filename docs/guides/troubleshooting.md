# Troubleshooting Guide

## Common Issues

### Plugin doesn't load

**Symptom**: Skills not available, contract not injected.

**Checks:**
1. Is `@ikieaneh/opencode-kit` in `opencode.json` plugin array? Must be **first**.
2. Is it installed? `ls node_modules/@ikieaneh/opencode-kit`
3. Is the plugin array syntax correct? `"plugin": ["@ikieaneh/opencode-kit"]`

### Agent jumps straight to implementation

**Symptom**: Agent starts working without loading contract.

**Fix:** The plugin's `messages.transform` hook injects the bootstrap. Make sure:
1. Plugin is first in the array
2. No other plugin overrides the same hook
3. Run `bash .opencode/src/doctor.sh` to verify

### Contract not found

**Symptom**: "Contract not found" error from preflight.

**Solution:**
```sh
bash .opencode/src/doctor.sh
# Or manually:
mkdir -p .opencode/orchestration
cp node_modules/@ikieaneh/opencode-kit/templates/contract.json .opencode/orchestration/contract.json
```

### Score below threshold

**Symptom**: Workflow keeps retrying or gets blocked.

**Check:**
- Tier 1 violations (blast radius, permissions)
- Tier 2 judge feedback — read `judge.missing_items`
- Retry count — max 3 attempts before BLOCKED

### ShellCheck fails in CI

**Symptom**: GitHub Actions ShellCheck job fails.

**Fix:** Run locally:
```sh
shellcheck src/*.sh rules/*.sh
```
Look for SC1091 (source path) or SC2001 (sed style) — most are info-level.

### Scaffold test fails in CI

**Symptom**: init.sh exits with error.

**Check:**
- Are all `mkdir -p` paths created before `cp`?
- Run locally: `cd /tmp && git init && bash /path/to/init.sh`

### Custom skill not loading

**Symptom**: Skill referenced in opencode.json not available.

**Solution:**
1. Place skill at `.opencode/skills/<name>/SKILL.md`
2. Verify frontmatter has `description:` field
3. Verify SKILL.md starts with `---` (YAML frontmatter)
4. Run `bash .opencode/src/doctor.sh` to verify

### Contract lock timeout
**Symptom**: "Could not acquire contract lock" error.

**Fix:**
```sh
# Check if lock exists
bash .opencode/src/contract-lock.sh check

# Force release stale lock (older than 5 minutes)
bash .opencode/src/contract-lock.sh force

# Force release ALL locks
bash .opencode/src/contract-lock.sh force --all
```

### Scoring pipeline fails
**Symptom**: "scoring-pipeline.sh: command not found" or scoring doesn't run.

**Fix:**
```sh
# Verify script exists and is executable
ls -la .opencode/src/scoring-pipeline.sh

# Run manually to see errors
bash .opencode/src/scoring-pipeline.sh 2>&1

# Check contract.json has required fields
bash .opencode/src/doctor.sh
```

### Adoption check fails
**Symptom**: "Project not initialized" or missing files error.

**Fix:**
```sh
# Run adoption check with fix mode
bash .opencode/src/adoption-check.sh --fix

# Or reinitialize manually
bash .opencode/src/init.sh
```

### Audit trail not recording
**Symptom**: No events in .opencode/audit/audit.log.

**Fix:**
```sh
# Check if audit directory exists
ls -la .opencode/audit/

# Create it manually if missing
mkdir -p .opencode/audit/

# Test logging
bash .opencode/src/audit-trail.sh log test "initialization" '{"test": true}'
```

### State machine validation fails in preflight
**Symptom**: "INVALID_STATE" or "NO_TRANSITION" warning in preflight.

**Fix:**
- Check contract.json state is one of: INIT, PLAN, PLAN_SCORED, EXECUTE, EXECUTE_SCORED, REVIEW, REVIEW_SCORED, COMPLETE, BLOCKED
- Verify rules.json has valid transitions for current state
- If stuck in BLOCKED, follow escalation protocol in templates/escalation.md

### Contract validation fails (contract-lint)
**Symptom**: "BLOCKED: Contract validation failed" or "contract.json not found" in preflight.
**Symptom**: Downstream project override breaks workflow.
```bash
# Run lint to see exact errors
bash .opencode/src/contract-lint.sh

# JSON output for debugging
bash .opencode/src/contract-lint.sh --json

# Validate a specific override file
bash .opencode/src/contract-lint.sh --contract .opencode/orchestration/contract.json --strict
```
Common causes:
- Missing required fields (state, session, scope, requirements, governance, validation, outputs, score, retry, metrics)
- Invalid state enum (must be INIT, PLAN, PLAN_SCORED, EXECUTE, EXECUTE_SCORED, REVIEW, REVIEW_SCORED, COMPLETE, BLOCKED)
- Wrong types (constraints as array instead of object, score.combined > 100)
- Missing nested fields (session.task_id, requirements.goal, score.verdict)

Fix: either add missing fields or re-scaffold with `bash .opencode/src/init.sh --force`

## Diagnostics

```sh
bash .opencode/src/doctor.sh           # Full health check
bash .opencode/src/status.sh           # Dashboard view
bash .opencode/src/analytics.sh        # Telemetry analysis
bash .opencode/src/adoption-check.sh   # Verify project adoption
bash .opencode/src/contract-lock.sh check  # Check contract lock status
bash .opencode/src/audit-trail.sh query    # Query audit events
bash .opencode/src/scoring-pipeline.sh     # Run scoring pipeline
bash .opencode/src/contract-lint.sh        # Validate contract structure
```
