#!/usr/bin/env bash
# ⛔ opencode-kit preflight — MANDATORY enforcement gate
# Must run before any tool call. Exits with error if rules violated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

CONTRACT_KEY="orchestration-contract"
RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "[opencode-kit] ⛔ Pre-flight check..."
ISSUES=0

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

# --- Check 6: Validate state machine transition ---
if [ -n "$PYTHON_CMD" ] && [ -f "$CONTRACT_FILE" ] && [ -f "$RULES_FILE" ]; then
  TRANSITION_OK=$($PYTHON_CMD -c "
import json, sys

try:
    with open('$CONTRACT_FILE') as f:
        contract = json.load(f)
    with open('$RULES_FILE') as f:
        rules = json.load(f)
    
    state = contract.get('state', 'UNKNOWN')
    transitions = rules.get('state_machine', {}).get('transitions', [])
    
    # Get valid target states (excluding wildcard transitions)
    valid_targets = set()
    for t in transitions:
        if t.get('from') == state or t.get('from') == '*':
            valid_targets.add(t.get('to'))
    
    # Also check if current state is a valid state at all
    all_states = set()
    for t in transitions:
        all_states.add(t.get('from'))
        all_states.add(t.get('to'))
    all_states.discard('*')
    
    if state not in all_states:
        print(f'INVALID_STATE:{state}')
        sys.exit(1)
    
    # For non-terminal states, check that a transition exists
    if state != 'COMPLETE' and state != 'BLOCKED' and state not in valid_targets:
        print(f'NO_TRANSITION:{state}')
        sys.exit(1)
    
    print(f'VALID:{state}')
    sys.exit(0)
except Exception as e:
    print(f'ERROR:{e}')
    sys.exit(1)
" 2>/dev/null || echo "SKIP")
  
  if [[ "$TRANSITION_OK" == INVALID_STATE:* ]]; then
    BAD_STATE="${TRANSITION_OK#INVALID_STATE:}"
    echo -e "${RED}  ⛔ STATE MACHINE: '$BAD_STATE' is not a valid contract state${NC}"
    echo -e "${RED}  → Valid states: INIT, PLAN, PLAN_SCORED, EXECUTE, EXECUTE_SCORED, REVIEW, REVIEW_SCORED, COMPLETE, BLOCKED${NC}"
    ISSUES=$((ISSUES + 1))
  elif [[ "$TRANSITION_OK" == NO_TRANSITION:* ]]; then
    CUR_STATE="${TRANSITION_OK#NO_TRANSITION:}"
    echo -e "${YELLOW}  ⚠️  STATE MACHINE: No valid transition from '$CUR_STATE'${NC}"
    echo -e "${YELLOW}  → Contract may need state update or BLOCKED recovery${NC}"
  elif [[ "$TRANSITION_OK" == VALID:* ]]; then
    echo "  ✅ State machine: transition valid from ${TRANSITION_OK#VALID:}"
  fi
fi

# --- Check 7: Model change detection ---
if [ -n "$PYTHON_CMD" ] && [ -f "opencode.json" ]; then
  MODEL_CHECK=$($PYTHON_CMD -c "
import json, sys

with open('opencode.json') as f:
    config = json.load(f)
config_model = config.get('model', '')

contract_model = ''
try:
    with open('$CONTRACT_FILE') as f:
        contract = json.load(f)
    contract_model = contract.get('session', {}).get('model', '')
except:
    pass

if not contract_model:
    print('NOTRACK')
    sys.exit(0)

if config_model != contract_model:
    print(f'MISMATCH|{contract_model}|{config_model}')
    sys.exit(0)

print(f'MATCH|{config_model}')
" 2>/dev/null || echo "PARSE_ERROR")

  IFS='|' read -r STATUS ARG1 ARG2 <<< "$MODEL_CHECK" || true

  case "$STATUS" in
    NOTRACK)
      echo -e "${YELLOW}  ⚠️  No model tracked in contract — run init to seed model${NC}"
      ISSUES=$((ISSUES + 1))
      ;;
    MISMATCH)
      echo -e "${RED}  ❌ MODEL MISMATCH: contract has '${ARG1}', opencode.json has '${ARG2}'${NC}"
      echo -e "${YELLOW}  ⚠️  Model change detected — new model may not have context from previous model's work${NC}"
      ISSUES=$((ISSUES + 2))
      ;;
    MATCH)
      echo -e "${GREEN}  ✅ Model tracked: ${ARG1}${NC}"
      ;;
    PARSE_ERROR)
      echo -e "${YELLOW}  ⚠️  Could not read model from opencode.json${NC}"
      ISSUES=$((ISSUES + 1))
      ;;
  esac
fi

# --- Check 8: Contract schema validation (hard block) ---
CONTRACT_LINT="$SCRIPT_DIR/contract-lint.sh"
if [ -f "$CONTRACT_LINT" ] && [ -f "$CONTRACT_FILE" ]; then
  LINT_EXIT=0
  "$CONTRACT_LINT" --contract "$CONTRACT_FILE" --strict 2>&1 || LINT_EXIT=$?
  if [ "$LINT_EXIT" -eq 1 ]; then
    echo -e "${RED}⛔ BLOCKED: Contract validation failed — fix errors before proceeding${NC}"
    ISSUES=$((ISSUES + 10))
  elif [ "$LINT_EXIT" -eq 3 ]; then
    echo -e "${RED}⛔ BLOCKED: contract.json not found — run: opencode-kit init${NC}"
    ISSUES=$((ISSUES + 10))
  fi
fi

# --- Check 9: Checkpoint validation (auto-fix if needed) ---
CHECKPOINT_FILE="$SCRIPT_DIR/checkpoint.sh"
if [ -f "$CHECKPOINT_FILE" ] && [ -f "$CONTRACT_FILE" ]; then
  # Check if there's a latest checkpoint
  CHECKPOINT_DIR=".opencode/orchestration/checkpoints"
  if [ -f "$CHECKPOINT_DIR/latest.json" ] && [ -n "$PYTHON_CMD" ]; then
    # Compare current contract with last checkpoint
    CP_DRIFT=$($PYTHON_CMD -c "
import json, sys
try:
    with open('$CHECKPOINT_DIR/latest.json') as f:
        cp = json.load(f)
    with open('$CONTRACT_FILE') as f:
        current = json.load(f)
    # Check if state differs from checkpoint
    cp_state = cp.get('state', '')
    cur_state = current.get('state', '')
    if cp_state != cur_state:
        print(f'STATE_CHANGE|{cp_state}|{cur_state}')
    else:
        print('NO_DRIFT')
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null || echo "ERROR")

    case "$CP_DRIFT" in
      STATE_CHANGE\|*)
        OLD_STATE="${CP_DRIFT#STATE_CHANGE|}"
        OLD_STATE="${OLD_STATE%%|*}"
        NEW_STATE="${CP_DRIFT##*|}"
        echo -e "${YELLOW}  ⚠️  Checkpoint drift: state changed from '$OLD_STATE' to '$NEW_STATE' since last checkpoint${NC}"
        # Auto-fix if contract-lint found issues
        if [ -f "$CONTRACT_LINT" ]; then
          LINT_CHECK=$("$CONTRACT_LINT" --contract "$CONTRACT_FILE" --json 2>/dev/null || echo '{"valid":true}')
          LINT_VALID=$($PYTHON_CMD -c "import json; print(json.loads('''$LINT_CHECK''').get('valid',True))" 2>/dev/null || echo "True")
          if [ "$LINT_VALID" = "False" ]; then
            echo -e "${YELLOW}  ⚠️  Contract has lint errors — running auto-fix...${NC}"
            "$CHECKPOINT_FILE" fix --json 2>/dev/null | head -5 || true
          fi
        fi
        ;;
      NO_DRIFT)
        echo "  ✅ Checkpoint: no drift from last checkpoint"
        ;;
      ERROR\|*)
        echo -e "${YELLOW}  ⚠️  Could not compare with last checkpoint${NC}"
        ;;
    esac
  elif [ -d "$CHECKPOINT_DIR" ]; then
    echo "  ℹ️  Checkpoint directory exists but no latest checkpoint"
  else
    echo "  ℹ️  No checkpoints yet — first save will create baseline"
  fi
fi

# --- Final verdict ---
if [ "$MCP_FAIL" -eq 1 ]; then
  echo -e "${RED}⛔ PREFLIGHT FAILED: Required MCPs not available.${NC}"
  echo -e "${RED}  → Ensure lean-ctx, gitnexus are configured in opencode.json MCP servers${NC}"
  exit 1
elif [ "$ISSUES" -gt 0 ]; then
  echo -e "${RED}⛔ PREFLIGHT FAILED: $ISSUES issue(s) found. Fix before proceeding.${NC}"
  exit 1
else
  echo "[opencode-kit] ✅ Pre-flight passed. All checks passed. Proceed."
fi
