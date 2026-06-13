#!/usr/bin/env bash
# opencode-kit scoring-pipeline — Tier 1 rule-based scoring
# Usage: bash src/scoring-pipeline.sh [--contract PATH] [--rules PATH] [--output PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"
# shellcheck source=./global-config.sh
. "$SCRIPT_DIR/global-config.sh"

# --- Default paths ---
CONTRACT_FILE=""
RULES_FILE=""
OUTPUT_FILE=""

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --contract) CONTRACT_FILE="$2"; shift 2 ;;
    --rules)    RULES_FILE="$2";    shift 2 ;;
    --output)   OUTPUT_FILE="$2";   shift 2 ;;
    *)          echo "Usage: $0 [--contract PATH] [--rules PATH] [--output PATH]" >&2; exit 1 ;;
  esac
done

# Resolve contract from project -> global -> plugin defaults
if [ -z "$CONTRACT_FILE" ]; then
  CONTRACT_FILE=$(resolve_config "orchestration/contract.json" 2>/dev/null || echo "")
fi
if [ -z "$CONTRACT_FILE" ] || [ ! -f "$CONTRACT_FILE" ]; then
  CONTRACT_FILE=".opencode/orchestration/contract.json"
fi

# Resolve rules from project -> global -> plugin defaults
if [ -z "$RULES_FILE" ]; then
  RULES_FILE=$(resolve_config "rules/rules.json" 2>/dev/null || echo "")
fi
if [ -z "$RULES_FILE" ] || [ ! -f "$RULES_FILE" ]; then
  RULES_FILE=".opencode/rules/rules.json"
fi
if [ ! -f "$RULES_FILE" ]; then
  RULES_FILE="rules/rules.json"
fi

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "[opencode-kit] Scoring pipeline -- Tier 1 rule-based checks"
echo "  Contract: $CONTRACT_FILE"
echo "  Rules:    $RULES_FILE"

# --- Validate inputs ---
VALID=1
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "${RED}  [MISSING] Contract file not found: $CONTRACT_FILE${NC}"
  VALID=0
fi
if [ ! -f "$RULES_FILE" ]; then
  echo -e "${RED}  [MISSING] Rules file not found: $RULES_FILE${NC}"
  VALID=0
fi
if [ "$VALID" -eq 0 ]; then
  echo -e "${RED}Scoring aborted -- missing required files.${NC}"
  exit 1
fi

# --- Run scoring logic via Python ---
if [ -z "$PYTHON_CMD" ]; then
  echo -e "${RED}  [ERROR] Python not available -- cannot compute scoring.${NC}"
  exit 1
fi

# Write scoring Python to temp file to avoid bash quoting nightmares
TMP_PYTHON_SCRIPT=$(mktemp /tmp/opencode-scoring-XXXXX.py)
trap 'rm -f "$TMP_PYTHON_SCRIPT"' EXIT INT TERM

cat > "$TMP_PYTHON_SCRIPT" << 'PYEOF'
import json, sys, os

contract_path = os.environ['CONTRACT_FILE']
rules_path    = os.environ['RULES_FILE']

# Load contract
with open(contract_path) as f:
    contract = json.load(f)

# Load rules
with open(rules_path) as f:
    rules = json.load(f)

# Extract scoring configuration
tier1 = rules.get('scoring', {}).get('tier1', {})
thresholds = rules.get('scoring', {}).get('thresholds', {})

schema_valid_deduction          = tier1.get('schema_valid_deduction', 15)
permissions_violated_deduction  = tier1.get('permissions_violated_deduction', 40)
blast_radius_high_deduction     = tier1.get('blast_radius_high_deduction', 40)
writing_order_wrong_deduction   = tier1.get('writing_order_wrong_deduction', 15)
required_fields_missing_deduction = tier1.get('required_fields_missing_deduction', 15)

pass_threshold   = thresholds.get('pass', 70)
retry_threshold  = thresholds.get('retry', 50)
max_attempts     = thresholds.get('max_attempts', 3)

deductions = []
score = 100

# -----------------------------------------------------------------------
# Check 1: Schema valid -- required fields present
required_contract_fields = ['state', 'session', 'scope', 'requirements',
                            'governance', 'validation', 'outputs', 'score',
                            'retry', 'metrics']
missing_fields = [f for f in required_contract_fields if f not in contract]

nested_checks = {
    'session':       ['task_id', 'branch', 'created_at'],
    'scope':         ['included', 'excluded', 'boundary'],
    'requirements':   ['goal'],
    'governance':     ['active_agent', 'mode', 'applicable_skills', 'permissions'],
    'score':          ['rules', 'judge', 'combined', 'verdict'],
}
nested_missing = []
for parent, children in nested_checks.items():
    if parent in contract and isinstance(contract[parent], dict):
        for child in children:
            if child not in contract[parent]:
                nested_missing.append(f'{parent}.{child}')

if missing_fields or nested_missing:
    score -= schema_valid_deduction
    deductions.append({
        'rule': 'schema_valid',
        'deduction': schema_valid_deduction,
        'reason': 'Required fields missing in contract',
        'details': {
            'missing_fields': missing_fields,
            'missing_nested': nested_missing
        }
    })

# -----------------------------------------------------------------------
# Check 2: Permissions violated -- SHELL_002 rule recorded as failed
permissions_violated = False
issues = contract.get('retry', {}).get('issues', [])
for issue in issues:
    if isinstance(issue, dict) and issue.get('rule') == 'SHELL_002':
        permissions_violated = True
        break
    if isinstance(issue, str) and 'SHELL_002' in issue:
        permissions_violated = True
        break

if permissions_violated:
    score -= permissions_violated_deduction
    deductions.append({
        'rule': 'permissions_violated',
        'deduction': permissions_violated_deduction,
        'reason': 'Agent used tools prohibited by governance.permissions (SHELL_002)'
    })

# -----------------------------------------------------------------------
# Check 3: Blast radius high -- IMPACT_001 or blast warnings ignored
blast_radius_ignored = False
previous_blockers = contract.get('governance', {}).get('previous_blockers', [])
for blocker in previous_blockers:
    if isinstance(blocker, str):
        lower = blocker.lower()
        if 'blast' in lower and ('high' in lower or 'critical' in lower):
            blast_radius_ignored = True
            break
    if isinstance(blocker, dict):
        text = json.dumps(blocker).lower()
        if 'blast' in text and ('high' in text or 'critical' in text):
            blast_radius_ignored = True
            break

decisions_log = contract.get('governance', {}).get('decisions_log', [])
for entry in decisions_log:
    if isinstance(entry, dict):
        text = json.dumps(entry).lower()
        if 'blast' in text and ('high' in text or 'critical' in text) and 'ignored' in text:
            blast_radius_ignored = True
            break

# Check for IMPACT_001 violations
rules_fail = contract.get('score', {}).get('rules', {}).get('fail', 0)
if not blast_radius_ignored:
    for issue in issues:
        if isinstance(issue, dict) and issue.get('rule') == 'IMPACT_001':
            blast_radius_ignored = True
            break
        if isinstance(issue, str) and 'IMPACT_001' in issue:
            blast_radius_ignored = True
            break

if blast_radius_ignored:
    score -= blast_radius_high_deduction
    deductions.append({
        'rule': 'blast_radius_high',
        'deduction': blast_radius_high_deduction,
        'reason': 'High/CRITICAL blast radius warning ignored or impact analysis skipped'
    })

# -----------------------------------------------------------------------
# Check 4: Writing order wrong
# Expected: port -> service -> mapper -> adapter -> constants -> events -> tests
code_changes = contract.get('outputs', {}).get('code_changes', [])
expected_order_keywords = ['port', 'service', 'mapper', 'adapter', 'constant', 'event', 'test']
writing_order_ok = True
writing_position = {}

if code_changes:
    for i, change in enumerate(code_changes):
        file_path = change.get('file', '')
        file_lower = file_path.lower()
        for keyword in expected_order_keywords:
            if keyword in file_lower:
                if keyword not in writing_position:
                    writing_position[keyword] = i
                break

    last_pos = -1
    for keyword in expected_order_keywords:
        if keyword in writing_position:
            pos = writing_position[keyword]
            if pos < last_pos:
                writing_order_ok = False
                break
            last_pos = pos

if not writing_order_ok:
    score -= writing_order_wrong_deduction
    deductions.append({
        'rule': 'writing_order_wrong',
        'deduction': writing_order_wrong_deduction,
        'reason': 'Files created in wrong order -- expected: port -> service -> mapper -> adapter -> constants -> events -> tests',
        'details': {
            'detected_order': {k: v for k, v in sorted(writing_position.items(), key=lambda x: x[1])}
        }
    })

# -----------------------------------------------------------------------
# Check 5: Required fields missing in outputs
outputs = contract.get('outputs', {})
output_checks = ['plan', 'code_changes', 'test_results', 'score_summary']
missing_outputs = []
for field_name in output_checks:
    val = outputs.get(field_name)
    if val is None:
        missing_outputs.append(field_name)
    elif isinstance(val, list) and len(val) == 0:
        missing_outputs.append(field_name)
    elif isinstance(val, dict) and len(val) == 0:
        missing_outputs.append(field_name)
    elif val == '':
        missing_outputs.append(field_name)

if missing_outputs:
    score -= required_fields_missing_deduction
    deductions.append({
        'rule': 'required_fields_missing',
        'deduction': required_fields_missing_deduction,
        'reason': 'Required output fields missing or empty',
        'details': {'missing_outputs': missing_outputs}
    })

# -----------------------------------------------------------------------
# Calculate final score (clamp to 0-100)
score = max(0, min(100, score))

# Determine verdict
if score >= pass_threshold:
    verdict = 'PASS'
elif score >= retry_threshold:
    verdict = 'RETRY'
else:
    verdict = 'BLOCKED'

# Build rationale
total_deduction = sum(item['deduction'] for item in deductions)
rationale_parts = []
if total_deduction == 0:
    rationale_parts.append('No Tier 1 rule violations detected.')
else:
    rationale_parts.append(
        f'Started at 100, deducted {total_deduction} points '
        f'across {len(deductions)} violation(s).')
    for item in deductions:
        rationale_parts.append(
            f"  - {item['rule']}: -{item['deduction']} ({item['reason']})")

if verdict == 'PASS':
    rationale_parts.append(
        f'Score {score} >= {pass_threshold} => PASS. '
        f'Eligible for Tier 2 LLM judge evaluation.')
elif verdict == 'RETRY':
    rationale_parts.append(
        f'Score {score} >= {retry_threshold} but < {pass_threshold} => RETRY. '
        f'Re-delegate with feedback.')
else:
    rationale_parts.append(
        f'Score {score} < {retry_threshold} => BLOCKED. '
        f'Escalate to user.')

rationale = '\n'.join(rationale_parts)

# Build result
result = {
    'score': score,
    'verdict': verdict,
    'deductions': deductions,
    'rationale': rationale,
    'thresholds': {
        'pass': pass_threshold,
        'retry': retry_threshold,
        'max_attempts': max_attempts,
    },
    'config_used': {
        'contract': contract_path,
        'rules': rules_path,
        'tier1_deductions': {
            'schema_valid': schema_valid_deduction,
            'permissions_violated': permissions_violated_deduction,
            'blast_radius_high': blast_radius_high_deduction,
            'writing_order_wrong': writing_order_wrong_deduction,
            'required_fields_missing': required_fields_missing_deduction,
        }
    }
}

print(json.dumps(result, indent=2))
PYEOF

# Run scoring script
SCORE_RESULT=$(CONTRACT_FILE="$CONTRACT_FILE" RULES_FILE="$RULES_FILE" $PYTHON_CMD "$TMP_PYTHON_SCRIPT" 2>&1) || {
  echo -e "${RED}  [ERROR] Python scoring failed:${NC}"
  echo "$SCORE_RESULT"
  exit 1
}

# --- Parse result fields ---
SCORE_VALUE=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "import json,sys; d=json.load(sys.stdin); print(d['score'])" 2>/dev/null || echo "0")
VERDICT_VALUE=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "import json,sys; d=json.load(sys.stdin); print(d['verdict'])" 2>/dev/null || echo "BLOCKED")
DEDUCTION_TOTAL=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "
import json,sys
d=json.load(sys.stdin)
total = sum(item['deduction'] for item in d['deductions'])
print(total)
" 2>/dev/null || echo "0")
DEDUCTION_COUNT=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "
import json,sys
d=json.load(sys.stdin)
print(len(d['deductions']))
" 2>/dev/null || echo "0")
RULE_PASS=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "
import json,sys
d=json.load(sys.stdin)
total = len(d['deductions'])
print(max(0, 5 - total))
" 2>/dev/null || echo "0")

# --- Update contract.json with score ---
$PYTHON_CMD -c "
import json

with open('$CONTRACT_FILE') as f:
    contract = json.load(f)

# Update score section
if 'score' not in contract:
    contract['score'] = {}

contract['score']['rules'] = {
    'pass': $RULE_PASS,
    'fail': $DEDUCTION_COUNT,
    'deduction': $DEDUCTION_TOTAL,
    'subtotal': $SCORE_VALUE
}
contract['score']['combined'] = $SCORE_VALUE
contract['score']['verdict'] = '$VERDICT_VALUE'

# Update state if BLOCKED
if '$VERDICT_VALUE' == 'BLOCKED':
    contract['state'] = 'BLOCKED'

# Track retry attempts for RETRY or BLOCKED
if '$VERDICT_VALUE' in ('RETRY', 'BLOCKED'):
    if 'retry' not in contract:
        contract['retry'] = {}
    contract['retry']['attempt'] = contract['retry'].get('attempt', 0) + 1
    if 'issues' not in contract['retry']:
        contract['retry']['issues'] = []

# Record model and timestamp in metrics
if 'metrics' not in contract:
    contract['metrics'] = {}
model = contract.get('session', {}).get('model', 'unknown')
contract['metrics']['model'] = model
contract['metrics']['scored_at'] = __import__('datetime').datetime.now().isoformat()

with open('$CONTRACT_FILE', 'w') as f:
    json.dump(contract, f, indent=2)

print('UPDATED')
" 2>&1 || echo "  [WARN] Failed to update contract"

# --- Display results ---
echo ""

DEDUCTIONS_DISPLAY=$(echo "$SCORE_RESULT" | $PYTHON_CMD -c "
import json,sys
d=json.load(sys.stdin)
lines = []
for item in d['deductions']:
    lines.append('  . ' + item['rule'] + ': -' + str(item['deduction']) + ' -- ' + item['reason'])
print('\\n'.join(lines))
" 2>/dev/null || true)

echo -e "${GREEN}========================================${NC}"
echo -e "  Score:   ${YELLOW}$SCORE_VALUE/100${NC}"

case "$VERDICT_VALUE" in
  PASS)    echo -e "  Verdict: ${GREEN}$VERDICT_VALUE${NC}" ;;
  RETRY)   echo -e "  Verdict: ${YELLOW}$VERDICT_VALUE${NC}" ;;
  BLOCKED) echo -e "  Verdict: ${RED}$VERDICT_VALUE${NC}" ;;
  *)       echo -e "  Verdict: $VERDICT_VALUE" ;;
esac

echo ""

if [ -n "$DEDUCTIONS_DISPLAY" ]; then
  echo "  Deductions:"
  echo "$DEDUCTIONS_DISPLAY"
  echo ""
fi

echo -e "${GREEN}========================================${NC}"

# --- Write output file if specified ---
if [ -n "$OUTPUT_FILE" ]; then
  echo "$SCORE_RESULT" > "$OUTPUT_FILE"
  echo "  Score result written to: $OUTPUT_FILE"
fi

# --- Persist to lean-ctx ---
if command -v lean-ctx &>/dev/null; then
  CONTRACT_JSON=$(cat "$CONTRACT_FILE")
  lean-ctx ctx_knowledge remember \
    category architecture \
    key orchestration-contract \
    value "$CONTRACT_JSON" 2>/dev/null && \
    echo "  Score persisted to lean-ctx" || \
    echo "  lean-ctx persistence skipped"
fi

echo "[opencode-kit] Scoring complete."

# Exit with code based on verdict
case "$VERDICT_VALUE" in
  PASS)    exit 0 ;;
  RETRY)   exit 2 ;;
  BLOCKED) exit 3 ;;
  *)       exit 1 ;;
esac
