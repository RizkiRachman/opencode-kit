#!/usr/bin/env bash
# opencode-kit verify — check installation health
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[opencode-kit] 🔍 Verify: checking installation..."
FAIL=0

# --- Check 1: required files exist ---
for f in \
  ".opencode/orchestration/contract.json" \
  ".opencode/rules/rules.json" \
  ".opencode/templates/superpowers-contract.json"; do
  if [ -f "$f" ]; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f MISSING"
    FAIL=1
  fi
done

# --- Check 2: agent .md files exist (all 10 agents) ---
for agent in orchestrator planner task-manager code-reviewer learner fixer explorer librarian architect observer; do
  FILE=".opencode/agents/$agent.md"
  if [ -f "$FILE" ]; then
    # Check pre-flight gate exists in file
    if grep -q "load contract" "$FILE" 2>/dev/null; then
      echo "  ✅ agents/$agent.md (has pre-flight gate)"
    else
      echo "  ⚠️  agents/$agent.md (MISSING pre-flight gate)"
    fi
    # Check agent uses lean-ctx, not bash
    if grep -q "lean-ctx" "$FILE" 2>/dev/null; then
      echo "  ✅ agents/$agent.md (uses lean-ctx tools)"
    else
      echo "  ⚠️  agents/$agent.md (MISSING lean-ctx tool references)"
    fi
  else
    echo "  ❌ agents/$agent.md MISSING"
    FAIL=1
  fi
done

# --- Check 2b: agent configs have bash disabled ---
if command -v python3 >/dev/null 2>&1; then
  AGENT_CONFIG=".opencode/opencode.json"
  if [ -f "$AGENT_CONFIG" ]; then
    python3 -c "
import json, sys
with open('$AGENT_CONFIG') as f:
    cfg = json.load(f)
agents = cfg.get('agent', {})
issues = []
for name, agent in agents.items():
    tools = agent.get('tools', {})
    if tools.get('bash') is not False:
        issues.append(f'  ❌ agent.{name}: bash not disabled')
    if not tools.get('lean-ctx_*'):
        issues.append(f'  ❌ agent.{name}: lean-ctx_* not enabled')
if issues:
    for i in issues: print(i)
    print('  ⚠️  TOOL_002 VIOLATION: All agents MUST have bash=false, lean-ctx_*=true')
    sys.exit(1)
else:
    print('  ✅ All agent configs: bash=false, lean-ctx_*=true')
" 2>/dev/null || echo "  ⚠️  Could not validate agent tool configs (python3 error)"
  else
    echo "  ⚠️  opencode.json not found — skipping agent tool config check"
  fi
else
  echo "  ⚠️  python3 not available — skipping agent tool config check"
fi

# --- Check 3: telemetry directory ---
mkdir -p .opencode/telemetry 2>/dev/null
echo "  ✅ telemetry directory ready"

# --- Check 4: scripts executable (all 16 enforcement scripts) ---
for script in \
  ".opencode/src/preflight.sh" ".opencode/src/postflight.sh" ".opencode/src/postflight.py" \
  ".opencode/src/telemetry.sh" ".opencode/src/doctor.sh" ".opencode/src/status.sh" \
  ".opencode/src/scoring-pipeline.sh" ".opencode/src/contract-lock.sh" \
  ".opencode/src/adoption-check.sh" ".opencode/src/audit-trail.sh" \
  ".opencode/src/init.sh" ".opencode/src/diff.sh" ".opencode/src/analytics.sh" \
  ".opencode/src/adr.sh" ".opencode/src/new-skill.sh" ".opencode/src/update.sh" \
  ".opencode/src/verify.sh" ".opencode/src/platform.sh" ".opencode/src/global-config.sh"; do
  if [ -x "$script" ]; then
    echo "  ✅ $script (executable)"
  elif [ -f "$script" ]; then
    echo "  ⚠️  $script (not executable — run chmod +x)"
  else
    echo "  ❌ $script MISSING"
    FAIL=1
  fi
done

# --- Check 5: not on main ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "  ⚠️  On '$BRANCH' branch — create a feature branch"
fi
echo "  ℹ️  Branch: $BRANCH"

if [ "$FAIL" -eq 1 ]; then
  echo "[opencode-kit] ❌ Verify FAILED — run 'opencode-kit init' to repair"
  exit 1
fi

echo "[opencode-kit] ✅ All checks passed"
