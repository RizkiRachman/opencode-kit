#!/usr/bin/env bash
# ⛔ opencode-kit preflight — MANDATORY enforcement gate
# Must run before any tool call. Exits with error if rules violated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

CONTRACT_KEY="orchestration-contract"
RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "[opencode-kit] ⛔ Pre-flight check..."

# --- Check 1: contract.json exists on disk ---
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "${RED}⛔ FAILED: $CONTRACT_FILE not found. Run 'opencode-kit init' first.${NC}"
  exit 1
fi
echo "  ✅ contract.json exists"

# --- Check 2: not on main ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo -e "${RED}⛔ FAILED: On '$BRANCH' branch. Create a feature branch first.${NC}"
  echo "  → git checkout -b feature/<YYYYMMDD>-<description>"
  exit 1
fi
echo "  ✅ Branch: $BRANCH (safe)"

# --- Check 3: MCP Availability (from rules.json) ---
echo ""
echo "  Checking MCP availability from rules.json..."

MCP_FAIL=0

if [ -n "$PYTHON_CMD" ] && [ -f "$RULES_FILE" ]; then
  # Parse required_mcps from rules.json
  $PYTHON_CMD -c "
import json, sys, subprocess, os

with open('$RULES_FILE') as f:
    rules = json.load(f)

mcps = rules.get('required_mcps', {})
if not isinstance(mcps, dict) or 'description' in mcps:
    # Skip the meta-description field
    mcps = {k: v for k, v in mcps.items() if k != 'description' and isinstance(v, dict)}

if not mcps:
    print('  ℹ️  No required_mcps defined in rules.json — skipping MCP checks')
    sys.exit(0)

failures = []
for name, cfg in mcps.items():
    cli_check = cfg.get('check_cli', '')
    tool_check = cfg.get('check_tool', '')
    severity = cfg.get('severity', 'optional')
    desc = cfg.get('description', name)

    available = False
    # Try CLI check first
    if cli_check:
        try:
            result = subprocess.run(cli_check, shell=True, capture_output=True, timeout=5)
            if result.returncode == 0:
                available = True
        except:
            pass

    # Try tool check as fallback
    if not available and tool_check:
        try:
            result = subprocess.run(tool_check, shell=True, capture_output=True, timeout=5)
            if result.returncode == 0:
                available = True
        except:
            pass

    if available:
        print(f'  ✅ {name}: available — {desc}')
    elif severity == 'required':
        print(f'  ❌ {name}: NOT DETECTED — {desc}')
        failures.append(name)
    else:
        print(f'  ⚠️  {name}: not detected — {desc} (optional)')

if failures:
    print('')
    for name in failures:
        print(f'  → Ensure {name} is configured in opencode.json MCP servers')
    sys.exit(1)
else:
    sys.exit(0)
" 2>&1 || MCP_FAIL=1
fi

echo ""

# --- Check 4: rules.json exists ---
if [ ! -f "$RULES_FILE" ]; then
  echo -e "${YELLOW}⚠️  WARNING: $RULES_FILE not found. Rules enforcement disabled.${NC}"
else
  echo "  ✅ rules.json found"
fi

# --- Telemetry: record phase start ---
mkdir -p .opencode/telemetry
echo $(date +%s) > .opencode/telemetry/.phase_start

# --- Check 5: contract state validation ---
if [ -n "$PYTHON_CMD" ] && [ -f "$CONTRACT_FILE" ]; then
  STATE=$($PYTHON_CMD -c "
import json,sys
try:
  with open('$CONTRACT_FILE') as f: d=json.load(f)
  print(d.get('state','UNKNOWN'))
except: print('PARSE_ERROR')
" 2>/dev/null)
  if [ "$STATE" = "PARSE_ERROR" ] || [ "$STATE" = "UNKNOWN" ]; then
    echo -e "${YELLOW}  ⚠️  Contract state: unknown — contract.json may be malformed${NC}"
  else
    echo "  ✅ Contract state: $STATE"
  fi
fi

# --- Final verdict ---
if [ "$MCP_FAIL" -eq 1 ]; then
  echo -e "${YELLOW}[opencode-kit] ⛔ Pre-flight completed with WARNINGS. Missing MCPs may cause failures.${NC}"
else
  echo "[opencode-kit] ✅ Pre-flight passed. All MCPs available. Proceed."
fi
