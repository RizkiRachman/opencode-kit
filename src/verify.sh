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

# --- Check 2: agent .md files exist ---
for agent in orchestrator planner task-manager code-reviewer learner fixer; do
  FILE=".opencode/agents/$agent.md"
  if [ -f "$FILE" ]; then
    # Check pre-flight gate exists in file
    if grep -q "load contract" "$FILE" 2>/dev/null; then
      echo "  ✅ agents/$agent.md (has pre-flight gate)"
    else
      echo "  ⚠️  agents/$agent.md (MISSING pre-flight gate)"
    fi
  else
    echo "  ❌ agents/$agent.md MISSING"
    FAIL=1
  fi
done

# --- Check 3: telemetry directory ---
mkdir -p .opencode/telemetry 2>/dev/null
echo "  ✅ telemetry directory ready"

# --- Check 4: scripts executable ---
for script in ".opencode/src/preflight.sh" ".opencode/src/postflight.sh" ".opencode/src/telemetry.sh" ".opencode/src/doctor.sh" ".opencode/src/status.sh"; do
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
