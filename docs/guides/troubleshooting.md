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

## Diagnostics

```sh
bash .opencode/src/doctor.sh       # Full health check
bash .opencode/src/status.sh       # Dashboard view
bash .opencode/src/analytics.sh    # Telemetry analysis
```
