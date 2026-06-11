#!/usr/bin/env bash
# opencode-kit diff — compare contract state between branches
# Usage: bash src/diff.sh [branch1] [branch2]
#   Default: compares current branch vs main
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

CONTRACT_FILE=".opencode/orchestration/contract.json"
BRANCH_A="${1:-main}"
BRANCH_B="${2:-HEAD}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}📋 opencode-kit diff: $BRANCH_A ↔ $BRANCH_B${NC}"
echo ""

# Extract contract from a git ref
get_contract_state() {
  local branch="$1"
  local content
  content=$(git show "$branch:$CONTRACT_FILE" 2>/dev/null || echo "")
  if [ -z "$content" ]; then
    echo ""
    return 1
  fi
  echo "$content"
}

CONTRACT_A=$(get_contract_state "$BRANCH_A")
CONTRACT_B=$(get_contract_state "$BRANCH_B")

if [ -z "$CONTRACT_A" ] && [ -z "$CONTRACT_B" ]; then
  echo -e "${YELLOW}No contract found in either branch.${NC}"
  exit 0
fi

# Show state diff
# Write contract data to temp files for safe Python consumption
CONTRACT_A_FILE=$(mktemp /tmp/opencode-diff-a-XXXXXX.json 2>/dev/null || mktemp /tmp/opencode-diff-a-XXXXXX)
CONTRACT_B_FILE=$(mktemp /tmp/opencode-diff-b-XXXXXX.json 2>/dev/null || mktemp /tmp/opencode-diff-b-XXXXXX)
trap 'rm -f "$CONTRACT_A_FILE" "$CONTRACT_B_FILE"' EXIT INT TERM

echo "$CONTRACT_A" > "$CONTRACT_A_FILE"
echo "$CONTRACT_B" > "$CONTRACT_B_FILE"

if [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json, sys

def get_state(filepath):
    try:
        with open(filepath) as f:
            content = f.read().strip()
        if not content:
            return None
        d = json.loads(content)
        return {
            'state': d.get('state', '?'),
            'goal': (d.get('requirements', {}) or {}).get('goal', '?'),
            'score': (d.get('score', {}) or {}).get('combined', '?'),
            'phases': (d.get('metrics', {}) or {}).get('phases_completed', []),
            'adrs': len((d.get('decisions', {}) or {}).get('adr_log', [])),
            'version': d.get('contract_version', '?')
        }
    except:
        return None

a = get_state('$CONTRACT_A_FILE')
b = get_state('$CONTRACT_B_FILE')

if a and b:
    print(f'  Field                   $BRANCH_A          $BRANCH_B')
    print(f'  {\"-\"*50}')
    for field in ['state', 'goal', 'score', 'version']:
        va = str(a.get(field, '?'))[:20]
        vb = str(b.get(field, '?'))[:20]
        marker = ' ←→' if va != vb else '   '
        print(f'  {field:20s}  {va:20s} {marker} {vb:20s}')
    print(f'  phases                 {len(a.get(\"phases\",[])):3d} completed     {len(b.get(\"phases\",[])):3d} completed')
    print(f'  ADRs                   {a.get(\"adrs\",0):3d} recorded      {b.get(\"adrs\",0):3d} recorded')
elif a and not b:
    print(f'  Contract exists in $BRANCH_A but NOT in $BRANCH_B')
    print(f'  State: {a.get(\"state\",\"?\")}')
elif b and not a:
    print(f'  Contract exists in $BRANCH_B but NOT in $BRANCH_A')
    print(f'  State: {b.get(\"state\",\"?\")}')
" 2>/dev/null || echo -e "${YELLOW}Could not parse contract JSON${NC}"

rm -f "$CONTRACT_A_FILE" "$CONTRACT_B_FILE"
fi

# Raw git diff
echo ""
echo -e "${CYAN}Raw diff:${NC}"
if git diff "$BRANCH_A" "$BRANCH_B" -- "$CONTRACT_FILE" 2>/dev/null | head -40; then
  if ! git diff --exit-code "$BRANCH_A" "$BRANCH_B" -- "$CONTRACT_FILE" &>/dev/null; then
    :
  fi
fi
echo ""
echo -e "Run: ${GREEN}bash .opencode/src/diff.sh${NC} (default: main vs HEAD)"
echo -e "     ${GREEN}bash .opencode/src/diff.sh staging feature-x${NC} (custom branches)"
