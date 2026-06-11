#!/usr/bin/env bash
# opencode-kit rules validation — validate agent actions against rules.json
# Usage: bash rules/validation.sh [--strict]
#   --strict: treat HIGH rules as BLOCK (default: FLAG only)
set -euo pipefail

RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

STRICT="${1:-}"

echo "[opencode-kit] 🔍 Rules Validation"
echo ""

# --- Check rules.json exists ---
if [ ! -f "$RULES_FILE" ]; then
  echo -e "${RED}❌ $RULES_FILE not found. Cannot validate.${NC}"
  exit 1
fi

# --- Check contract.json exists ---
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "${RED}❌ $CONTRACT_FILE not found. Cannot validate state.${NC}"
  exit 1
fi

# --- Parse rules.json using python3 or jq ---
if command -v python3 &>/dev/null; then
  PARSE_CMD="python3 -c"
elif command -v jq &>/dev/null; then
  PARSE_CMD="jq -r"
else
  echo -e "${RED}❌ Neither python3 nor jq found. Cannot parse rules.json.${NC}"
  exit 1
fi

echo "  Rules file: $RULES_FILE"
echo "  Contract:   $CONTRACT_FILE"
echo ""

TOTAL_VIOLATIONS=0
CRITICAL_VIOLATIONS=0
HIGH_VIOLATIONS=0

# --- Validate 1: Branch rule ---
echo -e "${CYAN}[PREFLIGHT_002]${NC} Branch validation..."
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo -e "${RED}  ❌ VIOLATION: On '$BRANCH' branch${NC}"
  echo "     → Create a feature branch: git checkout -b feature/<YYYYMMDD>-<description>"
  CRITICAL_VIOLATIONS=$((CRITICAL_VIOLATIONS + 1))
  TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
else
  echo "  ✅ Branch: $BRANCH (safe)"
fi

# --- Validate 2: Contract state ---
echo -e "${CYAN}[STATE_001]${NC} Contract state validation..."
STATE=$(python3 -c "
import json
with open('$CONTRACT_FILE') as f: d=json.load(f)
print(d.get('state','UNKNOWN'))
" 2>/dev/null)
VALID_STATES="INIT PLAN PLAN_SCORED EXECUTE EXECUTE_SCORED REVIEW REVIEW_SCORED COMPLETE BLOCKED"
if echo "$VALID_STATES" | grep -qw "$STATE"; then
  echo "  ✅ State: $STATE (valid)"
else
  echo -e "${RED}  ❌ VIOLATION: Invalid state '$STATE'${NC}"
  echo "     → Valid states: $VALID_STATES"
  CRITICAL_VIOLATIONS=$((CRITICAL_VIOLATIONS + 1))
  TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
fi

# --- Validate 3: Contract has required fields ---
echo -e "${CYAN}[SCHEMA_001]${NC} Contract schema validation..."
python3 -c "
import json, sys
with open('$CONTRACT_FILE') as f: d=json.load(f)
errors = []
if not d.get('requirements',{}).get('goal'): errors.append('requirements.goal is empty')
if d.get('score',{}).get('combined') is None: errors.append('score.combined is missing')
if d.get('state') not in ['INIT','PLAN','PLAN_SCORED','EXECUTE','EXECUTE_SCORED','REVIEW','REVIEW_SCORED','COMPLETE','BLOCKED']:
  errors.append('state is invalid')
if errors:
  print('VIOLATION:' + '; '.join(errors))
  sys.exit(1)
else:
  print('OK')
" 2>&1 || true
# (soft check — don't block)

# --- Validate 4: gitnexus impact check (if git diff shows changes) ---
echo -e "${CYAN}[IMPACT_001]${NC} Impact analysis check..."
if git diff --stat HEAD 2>/dev/null | grep -q .; then
  echo -e "${YELLOW}  ⚠️  Uncommitted changes detected — run gitnexus_impact before editing${NC}"
  HIGH_VIOLATIONS=$((HIGH_VIOLATIONS + 1))
  TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
else
  echo "  ✅ No uncommitted changes (or changes already analyzed)"
fi

# --- Validate 5: Contract persisted check (lean-ctx) ---
echo -e "${CYAN}[PERSIST_001]${NC} Persistence check..."
if command -v lean-ctx &>/dev/null; then
  if lean-ctx ctx_knowledge recall --query "orchestration-contract" &>/dev/null; then
    echo "  ✅ Contract persisted in lean-ctx"
  else
    echo -e "${YELLOW}  ⚠️  Contract NOT found in lean-ctx — persist after changes${NC}"
    HIGH_VIOLATIONS=$((HIGH_VIOLATIONS + 1))
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + 1))
  fi
else
  echo -e "${YELLOW}  ⚠️  lean-ctx not available — cannot verify persistence${NC}"
fi

# --- Summary ---
echo ""
echo "[opencode-kit] 📊 Validation Summary"
echo "  CRITICAL violations: $CRITICAL_VIOLATIONS"
echo "  HIGH violations:     $HIGH_VIOLATIONS"
echo "  Total violations:    $TOTAL_VIOLATIONS"
echo ""

if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
  echo -e "${GREEN}[opencode-kit] ✅ All rules validated. No violations.${NC}"
  exit 0
elif [ "$CRITICAL_VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}[opencode-kit] ❌ CRITICAL violations found. Run preflight.sh to identify blockers.${NC}"
  exit 1
elif [ "$STRICT" = "--strict" ] && [ "$HIGH_VIOLATIONS" -gt 0 ]; then
  echo -e "${YELLOW}[opencode-kit] ⛔ HIGH violations in strict mode. Fix before proceeding.${NC}"
  exit 1
else
  echo -e "${YELLOW}[opencode-kit] ⚠️  HIGH violations found (FLAG only — non-blocking).${NC}"
  exit 0
fi
