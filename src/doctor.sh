#!/usr/bin/env bash
# opencode-kit doctor — diagnostic command
# Checks: MCPs, contract, rules, permissions, git branch, agent configs
# Usage: bash src/doctor.sh [--json] [--fix]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"
. "$SCRIPT_DIR/global-config.sh"

RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"
OPENCODE_JSON="opencode.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ISSUES=0
mode="${1:-}"

echo -e "${CYAN}🔍 opencode-kit doctor${NC}"
echo ""

# === 1. Contract check ===
echo -e "${CYAN}[CONTRACT]${NC} Checking orchestration contract..."
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "  ${RED}❌ contract.json not found — run 'opencode-kit init'${NC}"
  ISSUES=$((ISSUES + 1))
else
  if [ -n "$PYTHON_CMD" ]; then
    STATE=$($PYTHON_CMD -c "import json; d=json.load(open('$CONTRACT_FILE')); print(d.get('state','?'))" 2>/dev/null || echo "parse_error")
    if [ "$STATE" = "parse_error" ]; then
      echo -e "  ${RED}❌ contract.json is malformed JSON${NC}"
      ISSUES=$((ISSUES + 1))
    else
      echo -e "  ✅ State: $STATE"
    fi
  fi
fi

# === 1b. Contract schema validation (strict) ===
if [ -f "$CONTRACT_FILE" ]; then
  LINT_RESULT=$("$SCRIPT_DIR/contract-lint.sh" --contract "$CONTRACT_FILE" --json 2>/dev/null || echo '{"valid":false,"errors":[{"field":"lint","message":"contract-lint.sh failed"}],"warnings":[]}')
  LINT_VALID=$($PYTHON_CMD -c "import json,sys; print(json.loads('''$LINT_RESULT''').get('valid',False))" 2>/dev/null || echo "False")
  LINT_ERRORS=$($PYTHON_CMD -c "import json,sys; print(len(json.loads('''$LINT_RESULT''').get('errors',[])))" 2>/dev/null || echo "0")
  LINT_WARNINGS=$($PYTHON_CMD -c "import json,sys; print(len(json.loads('''$LINT_RESULT''').get('warnings',[])))" 2>/dev/null || echo "0")

  if [ "$LINT_VALID" = "True" ]; then
    if [ "$LINT_WARNINGS" -gt 0 ]; then
      echo -e "  ⚠️  Contract valid with $LINT_WARNINGS warning(s)"
    else
      echo -e "  ✅ Contract schema valid"
    fi
  else
    echo -e "  ${RED}❌ Contract validation FAILED — $LINT_ERRORS error(s)${NC}"
    # Print individual errors
    $PYTHON_CMD -c "
import json
data = json.loads('''$LINT_RESULT''')
for e in data.get('errors', []):
    print(f\"  {chr(27)}[0;31m  ✗ {e['field']}: {e['message']}{chr(27)}[0m\")
" 2>/dev/null || true
    ISSUES=$((ISSUES + 1))
  fi
fi

# === 2. Rules check ===
echo -e "${CYAN}[RULES]${NC} Checking rules.json..."
if [ ! -f "$RULES_FILE" ]; then
  echo -e "  ${RED}❌ rules.json not found${NC}"
  ISSUES=$((ISSUES + 1))
else
  if [ -n "$PYTHON_CMD" ]; then
    RULE_COUNT=$($PYTHON_CMD -c "import json; d=json.load(open('$RULES_FILE')); print(len(d.get('rules',[])))" 2>/dev/null || echo "0")
    echo -e "  ✅ $RULE_COUNT rules loaded"
  fi
fi

# === 3a. MCP CLI checks ===
echo -e "${CYAN}[MCP]${NC} Checking required MCPs..."
if [ -f "$RULES_FILE" ] && [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json, shlex, subprocess, sys
with open('$RULES_FILE') as f:
    rules = json.load(f)
mcps = rules.get('required_mcps', {})
mcps.pop('description', None)
for name, cfg in mcps.items():
    cli = cfg.get('check_cli', '')
    if not cli:
        print(f'  ⚠️  {name}: no check_cli configured')
        continue
    severity = cfg.get('severity', 'optional')
    result = subprocess.run(shlex.split(cli), capture_output=True, timeout=5)
    ok = result.returncode == 0
    if ok:
        print(f'  ✅ {name}: available')
    elif severity == 'required':
        print(f'  ❌ {name}: MISSING (required)')
        sys.exit(1)
    else:
        print(f'  ⚠️  {name}: not detected (optional)')
" 2>/dev/null || ISSUES=$((ISSUES + 1))
fi

# === 3b. MCP connectivity ===
echo -e "${CYAN}[MCP_CONNECT]${NC} Testing MCP connectivity..."
if command -v lean-ctx &>/dev/null; then
  if lean-ctx ctx_knowledge status &>/dev/null 2>&1; then
    echo -e "  ✅ lean-ctx MCP: responding"
  else
    echo -e "  ⚠️  lean-ctx CLI found but MCP not responding (expected in CI)"
  fi
fi

# === 4. Git branch ===
echo -e "${CYAN}[GIT]${NC} Checking branch..."
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo -e "  ${YELLOW}⚠️  On '$BRANCH' — create a feature branch for development${NC}"
else
  echo -e "  ✅ Branch: $BRANCH"
fi

# === 5. Lean-ctx persistence ===
echo -e "${CYAN}[PERSIST]${NC} Checking persistence..."
if command -v lean-ctx &>/dev/null; then
  echo -e "  ✅ lean-ctx CLI available"
  LEAN_OK=$(lean-ctx ctx_knowledge recall --query "orchestration-contract" &>/dev/null && echo "yes" || echo "no")
  if [ "$LEAN_OK" = "yes" ]; then
    echo -e "  ✅ Contract found in lean-ctx"
  else
    echo -e "  ⚠️  Contract not in lean-ctx (file fallback active)"
  fi
else
  echo -e "  ⚠️  lean-ctx not detected (file fallback active)"
fi

# === 6. Plugin in opencode.json ===
echo -e "${CYAN}[PLUGIN]${NC} Checking plugin configuration..."
if [ -f "$OPENCODE_JSON" ]; then
  if grep -q "@ikieaneh/opencode-kit" "$OPENCODE_JSON" 2>/dev/null; then
    echo -e "  ✅ Plugin registered in opencode.json"
  else
    echo -e "  ${YELLOW}⚠️  Plugin not found in opencode.json — add to your plugin array${NC}"
  fi
else
  echo -e "  ${YELLOW}⚠️  No opencode.json found${NC}"
fi

# === Summary ===
echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed. System healthy.${NC}"
  exit 0
else
  echo -e "${RED}❌ $ISSUES issue(s) found. Review warnings above.${NC}"
  exit 1
fi
