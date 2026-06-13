#!/usr/bin/env bash
# opencode-kit checkpoint — save/validate/restore/fix orchestration step checkpoints
# Commands: save, validate, fix, list, restore <id>, latest, cleanup
# Usage: bash src/checkpoint.sh save [--agent <name>] [--step <name>] [--summary "<text>"] [--fix] [--json]
#        bash src/checkpoint.sh validate [--json]
#        bash src/checkpoint.sh fix [--json]
#        bash src/checkpoint.sh list [--json]
#        bash src/checkpoint.sh restore <id> [--json]
#        bash src/checkpoint.sh latest [--json]
#        bash src/checkpoint.sh cleanup [--json]
# Exit codes: 0=success, 1=error, 2=validation failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

CONTRACT_FILE=".opencode/orchestration/contract.json"
CHECKPOINT_DIR=".opencode/orchestration/checkpoints"
LATEST_FILE="$CHECKPOINT_DIR/latest.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ISO_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_ID=$(date -u +"%Y%m%d-%H%M%S")

# Parse global flags
COMMAND=""
AGENT_NAME="orchestrator"
STEP_NAME="unknown"
CONTEXT_SUMMARY=""
JSON_OUTPUT=false
FIX_MODE=false

# --- Help function ---
show_help() {
  echo "opencode-kit checkpoint — Orchestration step checkpoint system"
  echo ""
  echo "Commands:"
  echo "  save                    Save checkpoint with current state"
  echo "  validate                Validate last checkpoint (lint + doctor)"
  echo "  fix                     Fix contract by syncing with template (remove extra, add missing, fix types)"
  echo "  list                    Show checkpoint history"
  echo "  restore <id>            Roll back to a specific checkpoint"
  echo "  latest                  Show the latest checkpoint"
  echo "  cleanup                 Remove old checkpoints, keep last 10"
  echo ""
  echo "Flags:"
  echo "  --agent <name>          Agent name (default: orchestrator)"
  echo "  --step <name>           Step name (default: unknown)"
  echo "  --summary \"<text>\"    Context summary"
  echo "  --fix                   Auto-fix contract with template on save (if validation fails)"
  echo "  --json                  Output as JSON"
  echo ""
  echo "Exit codes:"
  echo "  0 = success"
  echo "  1 = error (missing contract, parse error)"
  echo "  2 = validation failed"
}

# --- Parse arguments ---
parse_args() {
  COMMAND=""
  AGENT_NAME="orchestrator"
  STEP_NAME="unknown"
  CONTEXT_SUMMARY=""
  JSON_OUTPUT=false
  FIX_MODE=false

  while [ $# -gt 0 ]; do
    case "$1" in
      save|validate|fix|list|latest|cleanup)
        COMMAND="$1"
        shift
        ;;
      restore)
        COMMAND="restore"
        shift
        if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
          RESTORE_ID="$1"
          shift
        else
          echo -e "${RED}Error: restore requires a checkpoint ID${NC}" >&2
          exit 1
        fi
        ;;
      --agent)
        shift
        AGENT_NAME="${1:-orchestrator}"
        shift
        ;;
      --step)
        shift
        STEP_NAME="${1:-unknown}"
        shift
        ;;
      --summary)
        shift
        CONTEXT_SUMMARY="${1:-}"
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --fix)
        FIX_MODE=true
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown argument: $1${NC}" >&2
        echo "Usage: bash src/checkpoint.sh <command> [flags]" >&2
        exit 1
        ;;
    esac
  done

  if [ -z "$COMMAND" ]; then
    echo -e "${RED}Error: No command specified. Use: save, validate, fix, list, restore <id>, latest, cleanup${NC}" >&2
    exit 1
  fi
}

# --- Git info helper ---
collect_git_info() {
  local branch="unknown"
  local commit="unknown"
  local dirty=false
  local uncommitted_files="[]"

  if git rev-parse --git-dir &>/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      dirty=true
      uncommitted_files=$($PYTHON_CMD -c "
import json, subprocess
result = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True, timeout=5)
files = []
for line in result.stdout.strip().split('\n'):
    line = line.strip()
    if line:
        files.append(line[3:])  # remove XY status prefix and space
print(json.dumps(files))
" 2>/dev/null || echo "[]")
    fi
  fi

  echo "{\"branch\":\"$branch\",\"commit\":\"$commit\",\"dirty\":$dirty,\"uncommitted_files\":$uncommitted_files}"
}

# --- Run validation (lint + doctor) ---
run_validation() {
  local lint_passed=false
  local doctor_passed=false
  local issues_json="[]"
  local lint_json="{}"
  local doctor_json="{}"
  local lint_exit=0
  local doctor_exit=0

  # Run contract-lint.sh --json
  if [ -f "$SCRIPT_DIR/contract-lint.sh" ]; then
    local lint_output
    lint_output=$("$SCRIPT_DIR/contract-lint.sh" 2>/dev/null || true)
    lint_exit=$?
    if [ -n "$lint_output" ]; then
      lint_json="$lint_output"
    fi
    if [ "$lint_exit" -eq 0 ] || [ "$lint_exit" -eq 2 ]; then
      lint_passed=true
    fi
  fi

  # Run doctor.sh --json (doctor doesn't natively support --json, so capture output and exit code)
  if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
    local doctor_output
    doctor_output=$("$SCRIPT_DIR/doctor.sh" 2>/dev/null || true)
    doctor_exit=$?
    if [ "$doctor_exit" -eq 0 ]; then
      doctor_passed=true
    fi
    doctor_json="{\"exit_code\":$doctor_exit}"
  fi

  # Collect issues from lint errors
  if [ "$lint_exit" -eq 1 ] && [ -n "$PYTHON_CMD" ]; then
    local lint_errors
    lint_errors=$($PYTHON_CMD -c "
import json, sys
try:
    data = json.loads('''$lint_json''')
    errors = data.get('errors', [])
    print(json.dumps(errors))
except:
    print('[]')
" 2>/dev/null || echo "[]")
    issues_json="$lint_errors"
  fi

  echo "{\"lint_passed\":$lint_passed,\"doctor_passed\":$doctor_passed,\"issues\":$issues_json,\"lint_exit\":$lint_exit,\"doctor_exit\":$doctor_exit}"
}

# --- command: fix ---
cmd_fix() {
  TEMPLATE_FILE=".opencode/templates/contract.json"
  # Also check plugin template location
  if [ ! -f "$TEMPLATE_FILE" ]; then
    SCRIPT_TEMPLATE="$(dirname "$SCRIPT_DIR")/templates/contract.json"
    if [ -f "$SCRIPT_TEMPLATE" ]; then
      TEMPLATE_FILE="$SCRIPT_TEMPLATE"
    fi
  fi

  if [ ! -f "$CONTRACT_FILE" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"contract.json not found","exit_code":1}'
    else
      echo -e "${RED}Error: $CONTRACT_FILE not found${NC}" >&2
    fi
    exit 1
  fi

  if [ ! -f "$TEMPLATE_FILE" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"template contract.json not found","exit_code":1}'
    else
      echo -e "${RED}Error: Template contract.json not found at $TEMPLATE_FILE${NC}" >&2
    fi
    exit 1
  fi

  if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}Error: Python required for fix${NC}" >&2
    exit 1
  fi

  # Run fix via Python: compare contract with template, fix mismatches
  local fix_result
  fix_result=$($PYTHON_CMD -c "
import json, sys, copy

TEMPLATE_PATH = '$TEMPLATE_FILE'
CONTRACT_PATH = '$CONTRACT_FILE'

with open(TEMPLATE_PATH) as f:
    template = json.load(f)

with open(CONTRACT_PATH) as f:
    contract = json.load(f)

def sync_fields(current, template_node, path=''):
    '''Recursively sync current with template structure.
    - Add missing fields from template (preserving current values)
    - Remove extra fields not in template
    - Fix type mismatches (reset to template default)
    Returns (fixed, changes_list).
    '''
    fixed = {}
    changes = []

    if not isinstance(template_node, dict):
        # Leaf node — can't recurse, return as-is
        return current, changes

    # Walk template keys (the source of truth)
    for key, template_val in template_node.items():
        if key in current:
            current_val = current[key]
            if isinstance(template_val, dict) and isinstance(current_val, dict):
                # Both are dicts — recurse
                merged, sub_changes = sync_fields(current_val, template_val, f'{path}.{key}')
                fixed[key] = merged
                changes.extend(sub_changes)
            elif type(template_val) != type(current_val) and template_val is not None:
                # Type mismatch — check if it's a simple fix
                # Allow int/float interchange
                if isinstance(template_val, (int, float)) and isinstance(current_val, (int, float)):
                    fixed[key] = current_val  # keep numeric
                elif isinstance(template_val, list) and isinstance(current_val, str):
                    # String that should be a list — wrap it
                    fixed[key] = [current_val]
                    changes.append({'action': 'type_fix', 'field': f'{path}.{key}', 'from': 'string', 'to': 'list'})
                elif isinstance(template_val, str) and isinstance(current_val, (int, float)):
                    # Number that should be string — convert
                    fixed[key] = str(current_val)
                    changes.append({'action': 'type_fix', 'field': f'{path}.{key}', 'from': str(type(current_val).__name__), 'to': 'string'})
                elif isinstance(template_val, dict) and not isinstance(current_val, dict):
                    # Should be dict but isn't — reset to template
                    fixed[key] = copy.deepcopy(template_val)
                    changes.append({'action': 'type_reset', 'field': f'{path}.{key}', 'reason': f'expected dict, got {type(current_val).__name__}'})
                elif isinstance(template_val, list) and not isinstance(current_val, list):
                    # Should be list but isn't — reset to template
                    fixed[key] = copy.deepcopy(template_val)
                    changes.append({'action': 'type_reset', 'field': f'{path}.{key}', 'reason': f'expected list, got {type(current_val).__name__}'})
                else:
                    fixed[key] = current_val  # keep as-is
            else:
                # Same type or template_val is None — keep current
                fixed[key] = current_val
        else:
            # Missing in current — add from template
            fixed[key] = copy.deepcopy(template_val)
            changes.append({'action': 'added', 'field': f'{path}.{key}'})

    # Check for extra keys in current not in template
    for key in current:
        if key not in template_node:
            changes.append({'action': 'removed', 'field': f'{path}.{key}', 'value_type': type(current[key]).__name__})
            # Don't add to fixed — this removes the extra field

    return fixed, changes

fixed_contract, changes = sync_fields(contract, template)

# Also check top-level extra keys
for key in list(contract.keys()):
    if key not in template:
        changes.append({'action': 'removed', 'field': key, 'value_type': type(contract[key]).__name__})

# Validate the fixed contract has all required top-level fields
required_top = ['state', 'session', 'scope', 'requirements', 'governance',
                'validation', 'outputs', 'score', 'retry', 'metrics']
missing = [f for f in required_top if f not in fixed_contract]
if missing:
    for m in missing:
        changes.append({'action': 'added', 'field': m, 'reason': 'required top-level field'})

# Count changes by type
added = [c for c in changes if c['action'] == 'added']
removed = [c for c in changes if c['action'] == 'removed']
type_fixes = [c for c in changes if c['action'] in ('type_fix', 'type_reset')]

result = {
    'changes': changes,
    'summary': {
        'total': len(changes),
        'added': len(added),
        'removed': len(removed),
        'type_fixed': len(type_fixes)
    },
    'valid': len(missing) == 0
}

if len(changes) > 0:
    # Write fixed contract
    with open(CONTRACT_PATH, 'w') as f:
        json.dump(fixed_contract, f, indent=2)
    result['wrote'] = True
else:
    result['wrote'] = False

print(json.dumps(result, indent=2))
" 2>&1)

  local fix_exit=$?

  if [ $fix_exit -ne 0 ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"fix failed","exit_code":1}'
    else
      echo -e "${RED}Error: Fix failed${NC}" >&2
      echo "$fix_result" >&2
    fi
    exit 1
  fi

  if $JSON_OUTPUT; then
    echo "$fix_result"
  else
    local total_changes
    total_changes=$($PYTHON_CMD -c "import json; print(json.loads('''$fix_result''').get('summary',{}).get('total',0))" 2>/dev/null || echo "0")
    local added_count
    added_count=$($PYTHON_CMD -c "import json; print(json.loads('''$fix_result''').get('summary',{}).get('added',0))" 2>/dev/null || echo "0")
    local removed_count
    removed_count=$($PYTHON_CMD -c "import json; print(json.loads('''$fix_result''').get('summary',{}).get('removed',0))" 2>/dev/null || echo "0")
    local type_fix_count
    type_fix_count=$($PYTHON_CMD -c "import json; print(json.loads('''$fix_result''').get('summary',{}).get('type_fixed',0))" 2>/dev/null || echo "0")
    local wrote
    wrote=$($PYTHON_CMD -c "import json; print(json.loads('''$fix_result''').get('wrote',False))" 2>/dev/null || echo "False")

    echo ""
    if [ "$total_changes" -eq 0 ]; then
      echo -e "${GREEN}✅ Contract is already in sync with template. No changes needed.${NC}"
    else
      echo -e "${CYAN}Contract fixed:${NC} $total_changes change(s)"
      [ "$added_count" -gt 0 ] && echo -e "  ${GREEN}+ $added_count field(s) added from template${NC}"
      [ "$removed_count" -gt 0 ] && echo -e "  ${YELLOW}- $removed_count extra field(s) removed${NC}"
      [ "$type_fix_count" -gt 0 ] && echo -e "  ${YELLOW}~ $type_fix_count type mismatch(es) fixed${NC}"
      echo ""

      # Re-validate after fix
      echo -e "${CYAN}Re-validating after fix...${NC}"
      local post_validation
      post_validation=$(run_validation)
      local post_lint
      post_lint=$($PYTHON_CMD -c "import json; v=json.loads('''$post_validation'''); print('PASS' if v.get('lint_passed') else 'FAIL')" 2>/dev/null || echo "?")
      local post_doctor
      post_doctor=$($PYTHON_CMD -c "import json; v=json.loads('''$post_validation'''); print('PASS' if v.get('doctor_passed') else 'FAIL')" 2>/dev/null || echo "?")
      echo -e "  Lint: $post_lint | Doctor: $post_doctor"

      if [ "$post_lint" = "PASS" ] && [ "$post_doctor" = "PASS" ]; then
        echo -e "${GREEN}✅ Contract now passes all validation checks${NC}"
      else
        echo -e "${YELLOW}⚠️  Some checks still failing — manual review may be needed${NC}"
      fi
    fi
  fi
}

# --- Internal fix helper (no output, used by cmd_save) ---
cmd_fix_internal() {
  TEMPLATE_FILE=".opencode/templates/contract.json"
  if [ ! -f "$TEMPLATE_FILE" ]; then
    SCRIPT_TEMPLATE="$(dirname "$SCRIPT_DIR")/templates/contract.json"
    if [ -f "$SCRIPT_TEMPLATE" ]; then
      TEMPLATE_FILE="$SCRIPT_TEMPLATE"
    fi
  fi

  if [ ! -f "$CONTRACT_FILE" ] || [ ! -f "$TEMPLATE_FILE" ] || [ -z "$PYTHON_CMD" ]; then
    return 1
  fi

  $PYTHON_CMD -c "
import json, copy

with open('$TEMPLATE_FILE') as f:
    template = json.load(f)
with open('$CONTRACT_FILE') as f:
    contract = json.load(f)

def sync_fields(current, template_node, path=''):
    fixed = {}
    for key, template_val in template_node.items():
        if key in current:
            current_val = current[key]
            if isinstance(template_val, dict) and isinstance(current_val, dict):
                fixed[key], _ = sync_fields(current_val, template_val, f'{path}.{key}')
            elif type(template_val) != type(current_val) and template_val is not None:
                if isinstance(template_val, (int, float)) and isinstance(current_val, (int, float)):
                    fixed[key] = current_val
                elif isinstance(template_val, list) and isinstance(current_val, str):
                    fixed[key] = [current_val]
                elif isinstance(template_val, dict) and not isinstance(current_val, dict):
                    fixed[key] = copy.deepcopy(template_val)
                elif isinstance(template_val, list) and not isinstance(current_val, list):
                    fixed[key] = copy.deepcopy(template_val)
                else:
                    fixed[key] = current_val
            else:
                fixed[key] = current_val
        else:
            fixed[key] = copy.deepcopy(template_val)
    return fixed, []

fixed, _ = sync_fields(contract, template)
with open('$CONTRACT_FILE', 'w') as f:
    json.dump(fixed, f, indent=2)
" 2>/dev/null || return 1
  return 0
}

# --- command: fix ---
cmd_save() {
  mkdir -p "$CHECKPOINT_DIR"

  # Read contract
  if [ ! -f "$CONTRACT_FILE" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"contract.json not found","exit_code":1}'
    else
      echo -e "${RED}Error: $CONTRACT_FILE not found${NC}" >&2
    fi
    exit 1
  fi

  local contract_content
  contract_content=$(cat "$CONTRACT_FILE")

  # Validate JSON
  if [ -n "$PYTHON_CMD" ]; then
    local parse_ok
    parse_ok=$($PYTHON_CMD -c "
import json, sys
try:
    json.loads('''$contract_content''')
    print('ok')
except json.JSONDecodeError as e:
    print(f'error: {e}')
" 2>/dev/null || echo "error: parse failed")
    if [[ "$parse_ok" != "ok" ]]; then
      if $JSON_OUTPUT; then
        echo '{"error":"contract.json is malformed JSON","exit_code":1}'
      else
        echo -e "${RED}Error: contract.json is malformed JSON${NC}" >&2
      fi
      exit 1
    fi
  fi

  # Get state from contract
  local state
  if [ -n "$PYTHON_CMD" ]; then
    state=$($PYTHON_CMD -c "
import json
d = json.loads('''$contract_content''')
print(d.get('state', 'UNKNOWN'))
" 2>/dev/null || echo "UNKNOWN")
  else
    state="UNKNOWN"
  fi

  # Collect git info
  local git_info
  if [ -n "$PYTHON_CMD" ]; then
    git_info=$(collect_git_info)
  else
    git_info='{"branch":"unknown","commit":"unknown","dirty":false,"uncommitted_files":[]}'
  fi

  # Run validation
  local validation_result
  if [ -n "$PYTHON_CMD" ]; then
    validation_result=$(run_validation)
  else
    validation_result='{"lint_passed":false,"doctor_passed":false,"issues":[],"lint_exit":0,"doctor_exit":0}'
  fi

  # Build checkpoint JSON
  local checkpoint_id="checkpoint-$TIMESTAMP_ID"
  local checkpoint_file="$CHECKPOINT_DIR/$checkpoint_id.json"

  if [ -n "$PYTHON_CMD" ]; then
    $PYTHON_CMD -c "
import json

checkpoint_id = '$checkpoint_id'
timestamp = '$ISO_TIMESTAMP'
state = '''$state'''
agent = '''$AGENT_NAME'''
step = '''$STEP_NAME'''
summary = '''$CONTEXT_SUMMARY'''
json_mode = '$JSON_OUTPUT' == 'true'

# Parse contract
contract = json.loads('''$contract_content''')

# Parse git info
git_info = json.loads('''$git_info''')

# Parse validation
validation = json.loads('''$validation_result''')

checkpoint = {
    'id': checkpoint_id,
    'timestamp': timestamp,
    'state': state,
    'agent': agent,
    'step': step,
    'contract_snapshot': contract,
    'git': git_info,
    'validation': {
        'lint_passed': validation.get('lint_passed', False),
        'doctor_passed': validation.get('doctor_passed', False),
        'issues': validation.get('issues', []),
        'lint_exit': validation.get('lint_exit', 0),
        'doctor_exit': validation.get('doctor_exit', 0)
    },
    'context_summary': summary
}

with open('$checkpoint_file', 'w') as f:
    json.dump(checkpoint, f, indent=2)

if json_mode:
    print(json.dumps(checkpoint))
" 2>/dev/null || {
      if $JSON_OUTPUT; then
        echo '{"error":"Failed to write checkpoint","exit_code":1}'
      else
        echo -e "${RED}Error: Failed to write checkpoint${NC}" >&2
      fi
      exit 1
    }
  else
    # Fallback without Python - minimal checkpoint
    cat > "$checkpoint_file" <<- EOFP
{
  "id": "$checkpoint_id",
  "timestamp": "$ISO_TIMESTAMP",
  "state": "$state",
  "agent": "$AGENT_NAME",
  "step": "$STEP_NAME",
  "contract_snapshot": $contract_content,
  "git": $git_info,
  "validation": {
    "lint_passed": false,
    "doctor_passed": false,
    "issues": [],
    "lint_exit": 0,
    "doctor_exit": 0
  },
  "context_summary": "$CONTEXT_SUMMARY"
}
EOFP
  fi

  # Update latest.json (copy, not symlink, for portability)
  cp "$checkpoint_file" "$LATEST_FILE"

  # Cleanup old checkpoints (keep last 10)
  cmd_cleanup_internal

  # Read validation status for summary
  local lint_status="PASS"
  local doctor_status="PASS"
  local validation_exit=0

  if [ -n "$PYTHON_CMD" ]; then
    local lint_passed_val
    local doctor_passed_val
    lint_passed_val=$($PYTHON_CMD -c "
import json
v = json.loads('''$validation_result''')
print('true' if v.get('lint_passed') else 'false')
" 2>/dev/null || echo "false")
    doctor_passed_val=$($PYTHON_CMD -c "
import json
v = json.loads('''$validation_result''')
print('true' if v.get('doctor_passed') else 'false')
" 2>/dev/null || echo "false")

    [ "$lint_passed_val" = "false" ] && lint_status="FAIL" && validation_exit=2
    [ "$doctor_passed_val" = "false" ] && doctor_status="FAIL" && validation_exit=2
  fi

  # Auto-fix mode: if validation failed and --fix is set, fix and re-save
  if [ "$validation_exit" -eq 2 ] && [ "$FIX_MODE" = "true" ]; then
    if ! $JSON_OUTPUT; then
      echo ""
      echo -e "${YELLOW}⚠️  Validation failed — running auto-fix (--fix mode)...${NC}"
    fi

    # Run fix
    cmd_fix_internal

    # Re-read fixed contract and re-validate
    if [ -n "$PYTHON_CMD" ]; then
      contract_content=$(cat "$CONTRACT_FILE")
      state=$($PYTHON_CMD -c "
import json
d = json.loads('''$contract_content''')
print(d.get('state', 'UNKNOWN'))
" 2>/dev/null || echo "UNKNOWN")

      # Re-validate
      validation_result=$(run_validation)

      # Re-check validation status
      lint_passed_val=$($PYTHON_CMD -c "
import json
v = json.loads('''$validation_result''')
print('true' if v.get('lint_passed') else 'false')
" 2>/dev/null || echo "false")
      doctor_passed_val=$($PYTHON_CMD -c "
import json
v = json.loads('''$validation_result''')
print('true' if v.get('doctor_passed') else 'false')
" 2>/dev/null || echo "false")

      lint_status="PASS"
      doctor_status="PASS"
      validation_exit=0
      [ "$lint_passed_val" = "false" ] && lint_status="FAIL" && validation_exit=2
      [ "$doctor_passed_val" = "false" ] && doctor_status="FAIL" && validation_exit=2

      if ! $JSON_OUTPUT; then
        echo ""
        echo -e "${CYAN}Re-saving checkpoint after fix...${NC}"
      fi
    fi
  fi

  if $JSON_OUTPUT; then
    $PYTHON_CMD -c "
import json
with open('$checkpoint_file') as f:
    cp = json.load(f)
cp['exit_code'] = $validation_exit
print(json.dumps(cp, indent=2))
" 2>/dev/null || cat "$checkpoint_file"
  else
    echo ""
    echo -e "${CYAN}Checkpoint saved:${NC} $checkpoint_id | ${CYAN}State:${NC} $state | ${CYAN}Lint:${NC} $lint_status | ${CYAN}Doctor:${NC} $doctor_status"
  fi

  exit "$validation_exit"
}

# --- command: validate ---
cmd_validate() {
  if [ ! -f "$LATEST_FILE" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"No checkpoint found. Run checkpoint save first.","exit_code":1}'
    else
      echo -e "${RED}Error: No checkpoint found. Run 'checkpoint save' first.${NC}" >&2
    fi
    exit 1
  fi

  if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}Error: Python required for validation${NC}" >&2
    exit 1
  fi

  # Run fresh validation
  local current_validation
  current_validation=$(run_validation)

  # Load stored validation from latest checkpoint
  local stored_validation
  stored_validation=$($PYTHON_CMD -c "
import json
with open('$LATEST_FILE') as f:
    cp = json.load(f)
print(json.dumps(cp.get('validation', {})))
" 2>/dev/null || echo '{}')

  # Compare and detect drift
  local drift_report
  drift_report=$($PYTHON_CMD -c "
import json

current = json.loads('''$current_validation''')
stored = json.loads('''$stored_validation''')

drift = []

# Compare lint status
if current.get('lint_passed') != stored.get('lint_passed'):
    drift.append({
        'check': 'lint',
        'stored': 'PASS' if stored.get('lint_passed') else 'FAIL',
        'current': 'PASS' if current.get('lint_passed') else 'FAIL'
    })

# Compare doctor status
if current.get('doctor_passed') != stored.get('doctor_passed'):
    drift.append({
        'check': 'doctor',
        'stored': 'PASS' if stored.get('doctor_passed') else 'FAIL',
        'current': 'PASS' if current.get('doctor_passed') else 'FAIL'
    })

# Compare issue count
stored_issues = len(stored.get('issues', []))
current_issues = len(current.get('issues', []))
if stored_issues != current_issues:
    drift.append({
        'check': 'issues',
        'stored': stored_issues,
        'current': current_issues
    })

print(json.dumps({
    'stored': stored,
    'current': current,
    'drift': drift,
    'has_drift': len(drift) > 0
}, indent=2))
" 2>/dev/null || echo '{"error":"comparison failed"}')

  local has_drift
  has_drift=$($PYTHON_CMD -c "
import json
print(json.loads('''$drift_report''').get('has_drift', False))
" 2>/dev/null || echo "false")

  if $JSON_OUTPUT; then
    echo "$drift_report"
  else
    local stored_lint
    local stored_doctor
    stored_lint=$($PYTHON_CMD -c "
import json
v = json.loads('''$stored_validation''')
print('PASS' if v.get('lint_passed') else 'FAIL')
" 2>/dev/null || echo "?")
    stored_doctor=$($PYTHON_CMD -c "
import json
v = json.loads('''$stored_validation''')
print('PASS' if v.get('doctor_passed') else 'FAIL')
" 2>/dev/null || echo "?")

    local current_lint
    local current_doctor
    current_lint=$($PYTHON_CMD -c "
import json
v = json.loads('''$current_validation''')
print('PASS' if v.get('lint_passed') else 'FAIL')
" 2>/dev/null || echo "?")
    current_doctor=$($PYTHON_CMD -c "
import json
v = json.loads('''$current_validation''')
print('PASS' if v.get('doctor_passed') else 'FAIL')
" 2>/dev/null || echo "?")

    echo ""
    echo -e "${CYAN}Checkpoint Validation Report${NC}"
    echo ""
    echo -e "  ${BOLD}Stored validation:${NC}  Lint: $stored_lint | Doctor: $stored_doctor"
    echo -e "  ${BOLD}Current state:${NC}     Lint: $current_lint | Doctor: $current_doctor"
    echo ""

    if [ "$has_drift" = "true" ]; then
      echo -e "  ${YELLOW}⚠️  Validation drift detected:${NC}"
      $PYTHON_CMD -c "
import json
report = json.loads('''$drift_report''')
for d in report.get('drift', []):
    check = d.get('check', '?')
    stored_val = d.get('stored', '?')
    current_val = d.get('current', '?')
    print(f\"    • {check}: stored={stored_val} → current={current_val}\")
" 2>/dev/null || true
      echo ""
      echo -e "  ${YELLOW}⚠️  Environment may have changed since checkpoint was saved${NC}"
    else
      echo -e "  ${GREEN}✅ No drift detected — validation state matches checkpoint${NC}"
    fi

    echo ""
    if [ "$current_lint" = "PASS" ] && [ "$current_doctor" = "PASS" ]; then
      echo -e "${GREEN}✅ All checks pass${NC}"
    else
      echo -e "${YELLOW}⚠️  Some checks are failing${NC}"
    fi
  fi
}

# --- command: list ---
cmd_list() {
  if [ ! -d "$CHECKPOINT_DIR" ]; then
    if $JSON_OUTPUT; then
      echo '{"checkpoints":[],"count":0}'
    else
      echo -e "${YELLOW}No checkpoints found.${NC}"
    fi
    exit 0
  fi

  # Find all checkpoint files (excluding latest.json)
  local checkpoint_files
  checkpoint_files=$(find "$CHECKPOINT_DIR" -name 'checkpoint-*.json' -type f | sort -r 2>/dev/null || true)

  if [ -z "$checkpoint_files" ]; then
    if $JSON_OUTPUT; then
      echo '{"checkpoints":[],"count":0}'
    else
      echo -e "${YELLOW}No checkpoints found.${NC}"
    fi
    exit 0
  fi

  if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}Python required for listing checkpoints${NC}" >&2
    exit 1
  fi

  if $JSON_OUTPUT; then
    $PYTHON_CMD -c "
import json, glob, os

checkpoints = []
files = sorted(glob.glob('$CHECKPOINT_DIR/checkpoint-*.json'), reverse=True)
for f in files:
    try:
        with open(f) as fh:
            cp = json.load(fh)
        checkpoints.append({
            'id': cp.get('id', os.path.basename(f)),
            'timestamp': cp.get('timestamp', ''),
            'state': cp.get('state', ''),
            'agent': cp.get('agent', ''),
            'step': cp.get('step', ''),
            'validation': cp.get('validation', {})
        })
    except:
        pass

print(json.dumps({'checkpoints': checkpoints, 'count': len(checkpoints)}, indent=2))
" 2>/dev/null || echo '{"error":"parse failed"}'
  else
    echo ""
    echo -e "${CYAN}Checkpoint History${NC}"
    echo ""
    printf "  %-30s %-22s %-14s %-18s %-14s %s\n" "ID" "Timestamp" "State" "Agent" "Step" "Validation"
    printf "  %-30s %-22s %-14s %-18s %-14s %s\n" "$(printf '%.30s' '------------------------------')" "$(printf '%.22s' '----------------------')" "$(printf '%.14s' '--------------')" "$(printf '%.18s' '------------------')" "$(printf '%.14s' '--------------')" "$(printf '%.14s' '--------------')"

    $PYTHON_CMD -c "
import json, glob, os

files = sorted(glob.glob('$CHECKPOINT_DIR/checkpoint-*.json'), reverse=True)
for f in files:
    try:
        with open(f) as fh:
            cp = json.load(fh)
        cid = cp.get('id', os.path.basename(f))
        ts = cp.get('timestamp', '')[:19]
        state = cp.get('state', '?')
        agent = cp.get('agent', '?')
        step = cp.get('step', '?')
        val = cp.get('validation', {})
        lint = 'P' if val.get('lint_passed') else 'F'
        doc = 'P' if val.get('doctor_passed') else 'F'
        print(f\"  {cid[:28]:30s} {ts:22s} {state:14s} {agent:18s} {step:14s} L:{lint} D:{doc}\")
    except:
        pass
" 2>/dev/null || echo "  (parse error)"
  fi
}

# --- command: restore ---
cmd_restore() {
  local target_id="$RESTORE_ID"

  if [ ! -d "$CHECKPOINT_DIR" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"No checkpoints directory found","exit_code":1}'
    else
      echo -e "${RED}Error: No checkpoints directory found.${NC}" >&2
    fi
    exit 1
  fi

  if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}Error: Python required for restore${NC}" >&2
    exit 1
  fi

  # Find checkpoint by ID (exact match or prefix match)
  local checkpoint_file=""
  if [ -f "$CHECKPOINT_DIR/$target_id.json" ]; then
    checkpoint_file="$CHECKPOINT_DIR/$target_id.json"
  elif [ -f "$CHECKPOINT_DIR/checkpoint-$target_id.json" ]; then
    checkpoint_file="$CHECKPOINT_DIR/checkpoint-$target_id.json"
  else
    # Search for partial match
    checkpoint_file=$($PYTHON_CMD -c "
import glob, os
target = '$target_id'
files = sorted(glob.glob('$CHECKPOINT_DIR/checkpoint-*.json'), reverse=True)
for f in files:
    cid = os.path.basename(f).replace('.json', '')
    if target in cid:
        print(f)
        break
" 2>/dev/null || true)
  fi

  if [ -z "$checkpoint_file" ] || [ ! -f "$checkpoint_file" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"Checkpoint not found","exit_code":1}'
    else
      echo -e "${RED}Error: Checkpoint '$target_id' not found${NC}" >&2
      echo "  Run 'checkpoint list' to see available checkpoints"
    fi
    exit 1
  fi

  # Read checkpoint and restore contract_snapshot
  local restore_info
  restore_info=$($PYTHON_CMD -c "
import json

with open('$checkpoint_file') as f:
    cp = json.load(f)

contract_snapshot = cp.get('contract_snapshot', {})
if not contract_snapshot:
    print(json.dumps({'error': 'No contract_snapshot in checkpoint', 'exit_code': 1}))
else:
    with open('$CONTRACT_FILE', 'w') as f:
        json.dump(contract_snapshot, f, indent=2)
    print(json.dumps({
        'id': cp.get('id', ''),
        'timestamp': cp.get('timestamp', ''),
        'state': cp.get('state', ''),
        'agent': cp.get('agent', ''),
        'step': cp.get('step', ''),
        'exit_code': 0
    }, indent=2))
" 2>/dev/null || echo '{"error":"restore failed","exit_code":1}')

  local restore_exit
  restore_exit=$($PYTHON_CMD -c "
import json
print(json.loads('''$restore_info''').get('exit_code', 1))
" 2>/dev/null || echo "1")

  if $JSON_OUTPUT; then
    echo "$restore_info"
  else
    local restored_id
    local restored_ts
    local restored_state
    restored_id=$($PYTHON_CMD -c "import json; print(json.loads('''$restore_info''').get('id','?'))" 2>/dev/null || echo "?")
    restored_ts=$($PYTHON_CMD -c "import json; print(json.loads('''$restore_info''').get('timestamp','?'))" 2>/dev/null || echo "?")
    restored_state=$($PYTHON_CMD -c "import json; print(json.loads('''$restore_info''').get('state','?'))" 2>/dev/null || echo "?")

    if [ "$restore_exit" -eq 0 ]; then
      echo ""
      echo -e "${GREEN}✅ Restored contract from:${NC} $restored_id"
      echo -e "   ${BOLD}Timestamp:${NC} $restored_ts"
      echo -e "   ${BOLD}State:${NC}     $restored_state"
      echo -e "   ${BOLD}Written to:${NC} $CONTRACT_FILE"
    else
      local error_msg
      error_msg=$($PYTHON_CMD -c "import json; print(json.loads('''$restore_info''').get('error','Unknown error'))" 2>/dev/null || echo "Unknown error")
      echo -e "${RED}Error: $error_msg${NC}" >&2
    fi
  fi

  exit "$restore_exit"
}

# --- command: latest ---
cmd_latest() {
  if [ ! -f "$LATEST_FILE" ]; then
    if $JSON_OUTPUT; then
      echo '{"error":"No latest checkpoint found","exit_code":1}'
    else
      echo -e "${YELLOW}No latest checkpoint found. Run 'checkpoint save' first.${NC}"
    fi
    exit 1
  fi

  if $JSON_OUTPUT; then
    cat "$LATEST_FILE"
  else
    echo ""
    if [ -n "$PYTHON_CMD" ]; then
      $PYTHON_CMD -c "
import json
with open('$LATEST_FILE') as f:
    cp = json.load(f)
print(json.dumps(cp, indent=2))
" 2>/dev/null || cat "$LATEST_FILE"
    else
      cat "$LATEST_FILE"
    fi
  fi
}

# --- Internal cleanup (no output) ---
cmd_cleanup_internal() {
  if [ ! -d "$CHECKPOINT_DIR" ]; then
    return 0
  fi

  if [ -z "$PYTHON_CMD" ]; then
    return 0
  fi

  $PYTHON_CMD -c "
import glob, os

checkpoint_dir = '$CHECKPOINT_DIR'
files = sorted(glob.glob(os.path.join(checkpoint_dir, 'checkpoint-*.json')))

# Keep last 10
keep = 10
if len(files) > keep:
    to_delete = files[:-keep]
    for f in to_delete:
        os.remove(f)
" 2>/dev/null || true

  # Always update latest.json symlink/copy to most recent checkpoint
  if [ -n "$PYTHON_CMD" ]; then
    local latest_checkpoint
    latest_checkpoint=$($PYTHON_CMD -c "
import glob, os
files = sorted(glob.glob('$CHECKPOINT_DIR/checkpoint-*.json'))
if files:
    print(files[-1])
" 2>/dev/null || true)
    if [ -n "$latest_checkpoint" ] && [ -f "$latest_checkpoint" ]; then
      cp "$latest_checkpoint" "$LATEST_FILE"
    fi
  fi
}

# --- command: cleanup ---
cmd_cleanup() {
  if [ ! -d "$CHECKPOINT_DIR" ]; then
    if $JSON_OUTPUT; then
      echo '{"deleted":0,"kept":0,"checkpoints_remaining":0}'
    else
      echo -e "${YELLOW}No checkpoints to clean up.${NC}"
    fi
    exit 0
  fi

  if [ -z "$PYTHON_CMD" ]; then
    # Basic fallback: keep 10 newest
    local count
    count=$(find "$CHECKPOINT_DIR" -name 'checkpoint-*.json' -type f | wc -l | tr -d ' ')
    if [ "$count" -gt 10 ]; then
      find "$CHECKPOINT_DIR" -name 'checkpoint-*.json' -type f | sort | head -n $((count - 10)) | xargs rm -f 2>/dev/null || true
    fi
    echo -e "${GREEN}✅ Cleaned up old checkpoints. Kept last 10.${NC}"
    exit 0
  fi

  local before_count
  before_count=$(find "$CHECKPOINT_DIR" -name 'checkpoint-*.json' -type f | wc -l | tr -d ' ')

  cmd_cleanup_internal

  local after_count
  after_count=$(find "$CHECKPOINT_DIR" -name 'checkpoint-*.json' -type f | wc -l | tr -d ' ')
  local deleted_count=$((before_count - after_count))

  if $JSON_OUTPUT; then
    $PYTHON_CMD -c "
import json
print(json.dumps({
    'deleted': $deleted_count,
    'kept': $after_count,
    'checkpoints_remaining': $after_count
}, indent=2))
" 2>/dev/null || echo "{\"deleted\":$deleted_count,\"kept\":$after_count,\"checkpoints_remaining\":$after_count}"
  else
    if [ "$deleted_count" -gt 0 ]; then
      echo -e "${GREEN}✅ Cleaned up $deleted_count old checkpoint(s). Kept last $after_count.${NC}"
    else
      echo -e "${GREEN}✅ No cleanup needed. $after_count checkpoint(s) (max 10).${NC}"
    fi
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
parse_args "$@"

case "$COMMAND" in
  save)
    cmd_save
    ;;
  validate)
    cmd_validate
    ;;
  fix)
    cmd_fix
    ;;
  list)
    cmd_list
    ;;
  restore)
    cmd_restore
    ;;
  latest)
    cmd_latest
    ;;
  cleanup)
    cmd_cleanup
    ;;
  *)
    echo -e "${RED}Error: Unknown command: $COMMAND${NC}" >&2
    echo "Usage: bash src/checkpoint.sh <command> [flags]" >&2
    exit 1
    ;;
esac
