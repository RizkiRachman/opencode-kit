#!/usr/bin/env bash
# opencode-kit contract-lint — validate contract.json structure and types
# Usage: bash src/contract-lint.sh [--contract path/to/contract.json] [--strict]
#   --strict    Exit non-zero on warnings (default: warnings are advisory)
#   --json      Output results as JSON
# Exit codes: 0=PASS, 1=ERRORS, 2=WARNING (non-strict), 3=NO_CONTRACT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Parse args ---
CONTRACT_FILE=""
STRICT=false
JSON_OUTPUT=false
for arg in "$@"; do
  case "$arg" in
    --contract) shift; CONTRACT_FILE="${1:-}"; shift ;;
    --strict) STRICT=true ;;
    --json) JSON_OUTPUT=true ;;
  esac
done

# --- Resolve contract file ---
if [ -z "$CONTRACT_FILE" ]; then
  for candidate in \
    ".opencode/orchestration/contract.json" \
    "contract.json" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode-kit/orchestration/contract.json"; do
    if [ -f "$candidate" ]; then
      CONTRACT_FILE="$candidate"
      break
    fi
  done
fi

if [ -z "$CONTRACT_FILE" ] || [ ! -f "$CONTRACT_FILE" ]; then
  if $JSON_OUTPUT; then
    echo '{"valid":false,"errors":[{"field":"contract","message":"contract.json not found"}],"warnings":[],"exit_code":3}'
  else
    echo -e "${RED}❌ contract.json not found${NC}"
    echo "  Searched: .opencode/orchestration/, project root, ~/.config/opencode-kit/"
    echo "  Run: opencode-kit init"
  fi
  exit 3
fi

# --- Validate with python3 ---
if [ -z "$PYTHON_CMD" ]; then
  echo -e "${YELLOW}⚠️  python3 not available — skipping contract validation${NC}"
  exit 0
fi

$PYTHON_CMD -c "
import json, sys, os

contract_path = '$CONTRACT_FILE'
errors = []
warnings = []

try:
    with open(contract_path) as f:
        contract = json.load(f)
except json.JSONDecodeError as e:
    errors.append({'field': 'root', 'message': f'Invalid JSON: {e}'})
    # Can't continue with broken JSON
    if '$JSON_OUTPUT' == 'true':
        import json as j
        print(j.dumps({'valid': False, 'errors': errors, 'warnings': warnings, 'exit_code': 1}))
    else:
        print(f'  {chr(27)}[0;31m❌ Invalid JSON: {e}{chr(27)}[0m')
    sys.exit(1)
except FileNotFoundError:
    errors.append({'field': 'root', 'message': 'File not found'})
    sys.exit(3)

if not isinstance(contract, dict):
    errors.append({'field': 'root', 'message': 'Contract must be a JSON object'})
    sys.exit(1)

# ============================================================
# CHECK 1: Required top-level fields
# ============================================================
required_top = ['state', 'session', 'scope', 'requirements', 'governance',
                'validation', 'outputs', 'score', 'retry', 'metrics']
for field in required_top:
    if field not in contract:
        errors.append({'field': field, 'message': f'Missing required field: {field}'})

# ============================================================
# CHECK 2: State enum validation
# ============================================================
valid_states = ['INIT', 'PLAN', 'PLAN_SCORED', 'EXECUTE', 'EXECUTE_SCORED',
                'REVIEW', 'REVIEW_SCORED', 'COMPLETE', 'BLOCKED']
state = contract.get('state', '')
if not state:
    errors.append({'field': 'state', 'message': 'State is empty'})
elif state not in valid_states:
    errors.append({'field': 'state', 'message': f'Invalid state: \"{state}\". Must be one of: {valid_states}'})

# ============================================================
# CHECK 3: Session fields
# ============================================================
session = contract.get('session', {})
if isinstance(session, dict):
    for field in ['task_id', 'branch', 'created_at']:
        if field not in session:
            warnings.append({'field': f'session.{field}', 'message': f'Missing session.{field}'})
    # Model tracking (recommended)
    if 'model' not in session:
        warnings.append({'field': 'session.model', 'message': 'Missing session.model — run init to seed'})
    elif not session.get('model'):
        warnings.append({'field': 'session.model', 'message': 'session.model is empty — model not tracked'})
elif 'session' in contract:
    errors.append({'field': 'session', 'message': 'session must be a JSON object'})

# ============================================================
# CHECK 4: Requirements fields
# ============================================================
reqs = contract.get('requirements', {})
if isinstance(reqs, dict):
    if not reqs.get('goal'):
        errors.append({'field': 'requirements.goal', 'message': 'requirements.goal is required and cannot be empty'})
    # Scope within requirements (optional but recommended)
    if 'scope' in reqs and isinstance(reqs['scope'], dict):
        if 'included' in reqs['scope'] and not isinstance(reqs['scope']['included'], list):
            errors.append({'field': 'requirements.scope.included', 'message': 'Must be an array'})
    if 'constraints' in reqs:
        if isinstance(reqs['constraints'], list):
            warnings.append({'field': 'requirements.constraints', 'message': 'constraints should be an object, not array'})
elif 'requirements' in contract:
    errors.append({'field': 'requirements', 'message': 'requirements must be a JSON object'})

# ============================================================
# CHECK 5: Governance fields
# ============================================================
gov = contract.get('governance', {})
if isinstance(gov, dict):
    if 'active_agent' not in gov:
        warnings.append({'field': 'governance.active_agent', 'message': 'Missing governance.active_agent'})
    if 'mode' in gov:
        valid_modes = ['autonomous', 'supervised', 'interactive']
        if gov['mode'] not in valid_modes:
            errors.append({'field': 'governance.mode', 'message': f'Invalid mode: \"{gov[\"mode\"]}\". Must be: {valid_modes}'})
    if 'permissions' in gov and isinstance(gov['permissions'], dict):
        perms = gov['permissions']
        if 'do' in perms and not isinstance(perms['do'], list):
            errors.append({'field': 'governance.permissions.do', 'message': 'Must be an array'})
        if 'dont' in perms and not isinstance(perms['dont'], list):
            errors.append({'field': 'governance.permissions.dont', 'message': 'Must be an array'})
elif 'governance' in contract:
    errors.append({'field': 'governance', 'message': 'governance must be a JSON object'})

# ============================================================
# CHECK 6: Score fields
# ============================================================
score = contract.get('score', {})
if isinstance(score, dict):
    if 'verdict' in score:
        valid_verdicts = ['INIT', 'PASS', 'RETRY', 'BLOCKED']
        if score['verdict'] not in valid_verdicts:
            errors.append({'field': 'score.verdict', 'message': f'Invalid verdict: \"{score[\"verdict\"]}\". Must be: {valid_verdicts}'})
    if 'combined' in score:
        val = score['combined']
        if not isinstance(val, (int, float)) or val < 0 or val > 100:
            errors.append({'field': 'score.combined', 'message': f'Must be a number 0-100, got: {val}'})
elif 'score' in contract:
    errors.append({'field': 'score', 'message': 'score must be a JSON object'})

# ============================================================
# CHECK 7: Retry fields
# ============================================================
retry = contract.get('retry', {})
if isinstance(retry, dict):
    if 'attempt' in retry:
        if not isinstance(retry['attempt'], int) or retry['attempt'] < 0:
            errors.append({'field': 'retry.attempt', 'message': 'Must be a non-negative integer'})
    if 'max_attempts' in retry:
        if not isinstance(retry['max_attempts'], int) or retry['max_attempts'] < 1:
            errors.append({'field': 'retry.max_attempts', 'message': 'Must be a positive integer'})
elif 'retry' in contract:
    errors.append({'field': 'retry', 'message': 'retry must be a JSON object'})

# ============================================================
# CHECK 8: Outputs type validation
# ============================================================
outputs = contract.get('outputs', {})
if isinstance(outputs, dict):
    if 'code_changes' in outputs and not isinstance(outputs['code_changes'], list):
        errors.append({'field': 'outputs.code_changes', 'message': 'Must be an array'})
    if 'agent_reports' in outputs and not isinstance(outputs['agent_reports'], list):
        errors.append({'field': 'outputs.agent_reports', 'message': 'Must be an array'})
elif 'outputs' in contract:
    errors.append({'field': 'outputs', 'message': 'outputs must be a JSON object'})

# ============================================================
# CHECK 9: Metrics type validation
# ============================================================
metrics = contract.get('metrics', {})
if isinstance(metrics, dict):
    if 'cost_tokens' in metrics and not isinstance(metrics['cost_tokens'], int):
        warnings.append({'field': 'metrics.cost_tokens', 'message': 'Should be an integer'})
    if 'elapsed_ms' in metrics and not isinstance(metrics['elapsed_ms'], int):
        warnings.append({'field': 'metrics.elapsed_ms', 'message': 'Should be an integer'})
    if 'agents_used' in metrics and not isinstance(metrics['agents_used'], list):
        errors.append({'field': 'metrics.agents_used', 'message': 'Must be an array'})
elif 'metrics' in contract:
    errors.append({'field': 'metrics', 'message': 'metrics must be a JSON object'})

# ============================================================
# CHECK 10: Required tools enforcement
# ============================================================
tools = contract.get('required_tools', {})
if isinstance(tools, dict) and tools.get('enforced'):
    tool_defs = tools.get('tools', {})
    if 'bash' in tool_defs and tool_defs['bash'].get('blocked') and tool_defs['bash'].get('required'):
        errors.append({'field': 'required_tools.tools.bash', 'message': 'bash cannot be both blocked and required'})
    if 'lean-ctx_*' in tool_defs and not tool_defs['lean-ctx_*'].get('required'):
        warnings.append({'field': 'required_tools.tools.lean-ctx_*', 'message': 'lean-ctx_* should be required'})

# ============================================================
# Summary
# ============================================================
has_errors = len(errors) > 0
has_warnings = len(warnings) > 0

if '$JSON_OUTPUT' == 'true':
    import json as j
    exit_code = 1 if has_errors else (2 if has_warnings else 0)
    print(j.dumps({
        'valid': not has_errors,
        'errors': errors,
        'warnings': warnings,
        'exit_code': exit_code,
        'contract_file': contract_path
    }, indent=2))
else:
    if has_errors:
        print(f'  {chr(27)}[0;31m❌ Contract validation FAILED — {len(errors)} error(s), {len(warnings)} warning(s){chr(27)}[0m')
        for e in errors:
            print(f'  {chr(27)}[0;31m  ✗ {e[\"field\"]}: {e[\"message\"]}{chr(27)}[0m')
        for w in warnings:
            print(f'  {chr(27)}[1;33m  ⚠ {w[\"field\"]}: {w[\"message\"]}{chr(27)}[0m')
    elif has_warnings:
        print(f'  {chr(27)}[1;33m⚠️  Contract valid with {len(warnings)} warning(s){chr(27)}[0m')
        for w in warnings:
            print(f'  {chr(27)}[1;33m  ⚠ {w[\"field\"]}: {w[\"message\"]}{chr(27)}[0m')
    else:
        print(f'  {chr(27)}[0;32m✅ Contract valid — all checks passed{chr(27)}[0m')

# Exit code logic
if has_errors:
    sys.exit(1)
elif has_warnings and '$STRICT' == 'true':
    sys.exit(2)
else:
    sys.exit(0)
" 2>&1
EXIT_CODE=$?

# Map exit codes to messages
case $EXIT_CODE in
  0) ;; # PASS — already printed by python
  1)
    if ! $JSON_OUTPUT; then
      echo -e "${RED}⛔ BLOCKED: Contract validation failed. Fix errors before proceeding.${NC}"
    fi
    ;;
  2)
    if ! $JSON_OUTPUT; then
      echo -e "${YELLOW}⚠️  Contract has warnings (non-blocking in normal mode)${NC}"
    fi
    ;;
  3)
    if ! $JSON_OUTPUT; then
      echo -e "${RED}❌ contract.json not found — run: opencode-kit init${NC}"
    fi
    ;;
esac

exit $EXIT_CODE
