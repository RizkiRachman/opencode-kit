#!/usr/bin/env bash
# opencode-kit adoption-check — Verify project has adopted opencode-kit
# Usage: bash src/adoption-check.sh [--fix]
#   --fix    Attempt to auto-fix missing components (run init)
#
# Checks:
#   1. .opencode/orchestration/contract.json exists
#   2. .opencode/rules/rules.json exists
#   3. At least .opencode/agents/orchestrator.md exists
#   4. opencode.json has @ikieaneh/opencode-kit in plugin array
#   5. contract.json has requirements.goal set (non-empty)
#   6. contract.json has scope defined
#
# Exit codes:
#   0 — All checks passed
#   1 — Issues found (non-fix mode)
#   2 — Issues remain after --fix attempt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ISSUES=0
FIX_MODE=false
[[ "${1:-}" == "--fix" ]] && FIX_MODE=true

echo "[opencode-kit] 🔍 Adoption check..."
echo ""

# --- Check 1: contract.json exists ---
echo "  [1/6] contract.json..."
CONTRACT=".opencode/orchestration/contract.json"
if [ -f "$CONTRACT" ]; then
  echo -e "    ${GREEN}✅ Found${NC}"
else
  echo -e "    ${RED}❌ MISSING: $CONTRACT${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Check 2: rules.json exists ---
echo "  [2/6] rules.json..."
RULES=".opencode/rules/rules.json"
if [ -f "$RULES" ]; then
  echo -e "    ${GREEN}✅ Found${NC}"
else
  echo -e "    ${RED}❌ MISSING: $RULES${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Check 3: agent templates exist ---
echo "  [3/6] Agent templates..."
AGENT_DIR=".opencode/agents"
AGENT_FOUND=false
if [ -d "$AGENT_DIR" ]; then
  for agent in orchestrator planner task-manager code-reviewer learner fixer explorer librarian architect observer; do
    if [ -f "$AGENT_DIR/$agent.md" ]; then
      AGENT_FOUND=true
      break
    fi
  done
fi
if [ "$AGENT_FOUND" = true ]; then
  echo -e "    ${GREEN}✅ At least orchestrator.md present${NC}"
else
  echo -e "    ${RED}❌ No agent templates found in $AGENT_DIR/${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Check 4: opencode.json has plugin ---
echo "  [4/6] opencode.json plugin..."
OPCODE="./opencode.json"
PLUGIN_OK=false
if [ -f "$OPCODE" ]; then
  # Use platform.sh json functions to check plugin array
  # Fallback: grep for the plugin string
  if grep -q '"@ikieaneh/opencode-kit"' "$OPCODE" 2>/dev/null; then
    PLUGIN_OK=true
  fi
fi
if [ "$PLUGIN_OK" = true ]; then
  echo -e "    ${GREEN}✅ @ikieaneh/opencode-kit plugin configured${NC}"
else
  echo -e "    ${RED}❌ @ikieaneh/opencode-kit not found in opencode.json plugins${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Check 5: contract has GOAL ---
echo "  [5/6] Contract GOAL..."
GOAL_OK=false
if [ -f "$CONTRACT" ]; then
  GOAL=$(json_get "$CONTRACT" "requirements.goal" 2>/dev/null || echo "")
  # Strip surrounding quotes if present
  GOAL_CLEAN=$(echo "$GOAL" | sed 's/^"//;s/"$//')
  if [ -n "$GOAL_CLEAN" ] && [ "$GOAL_CLEAN" != "null" ]; then
    GOAL_OK=true
  fi
fi
if [ "$GOAL_OK" = true ]; then
  echo -e "    ${GREEN}✅ requirements.goal is set${NC}"
else
  echo -e "    ${RED}❌ requirements.goal is empty or missing in contract.json${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Check 6: contract has SCOPE ---
echo "  [6/6] Contract SCOPE..."
SCOPE_OK=false
if [ -f "$CONTRACT" ]; then
  # Check that scope.included is an array (even empty) or scope has content
  HAS_SCOPE=$(json_has_field "$CONTRACT" "scope.included" 2>/dev/null && echo "true" || echo "false")
  HAS_REQ_SCOPE=$(json_has_field "$CONTRACT" "requirements.scope" 2>/dev/null && echo "true" || echo "false")
  if [ "$HAS_SCOPE" = "true" ] || [ "$HAS_REQ_SCOPE" = "true" ]; then
    SCOPE_OK=true
  fi
fi
if [ "$SCOPE_OK" = true ]; then
  echo -e "    ${GREEN}✅ scope is defined${NC}"
else
  echo -e "    ${RED}❌ scope (scope.included or requirements.scope) missing in contract.json${NC}"
  ISSUES=$((ISSUES + 1))
fi

# --- Summary ---
echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}[opencode-kit] ✅ All 6 adoption checks passed!${NC}"
  exit 0
fi

echo -e "${RED}[opencode-kit] ❌ $ISSUES adoption check(s) failed${NC}"

# --- Fix mode: run init ---
if [ "$FIX_MODE" = true ]; then
  echo ""
  echo -e "${YELLOW}[opencode-kit] 🛠️  --fix mode: running init to repair...${NC}"
  echo ""
  if bash "$SCRIPT_DIR/init.sh"; then
    echo ""
    echo -e "${GREEN}[opencode-kit] ✅ init completed. Re-running checks...${NC}"
    echo ""
    # Re-execute self without --fix to re-check
    exec bash "$0"
  else
    echo -e "${RED}[opencode-kit] ❌ init failed. Fix issues manually.${NC}"
    exit 2
  fi
else
  echo ""
  echo -e "${YELLOW}  Run with --fix to auto-repair, or check:${NC}"
  echo "    - .opencode/orchestration/contract.json"
  echo "    - .opencode/rules/rules.json"
  echo "    - .opencode/agents/ (needs at least orchestrator.md)"
  echo "    - opencode.json (needs @ikieaneh/opencode-kit plugin)"
  exit 1
fi
