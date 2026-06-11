#!/usr/bin/env bash
# opencode-kit ADR — auto-generate Architecture Decision Record
# Usage: bash src/adr.sh <title>
# Then enter context, decision, alternatives, consequences interactively.
# Or: bash src/adr.sh --title "<title>" --context "<context>" --decision "<decision>"
set -euo pipefail

CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Check contract exists ---
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "${RED}❌ $CONTRACT_FILE not found. Run 'opencode-kit init' first.${NC}"
  exit 1
fi

# --- Parse args ---
TITLE=""
CONTEXT=""
DECISION=""
ALTERNATIVES=""
CONSEQUENCES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title|-t) TITLE="$2"; shift 2 ;;
    --context|-c) CONTEXT="$2"; shift 2 ;;
    --decision|-d) DECISION="$2"; shift 2 ;;
    --alternatives|-a) ALTERNATIVES="$2"; shift 2 ;;
    --consequences|-q) CONSEQUENCES="$2"; shift 2 ;;
    *) TITLE="$1"; shift ;;
  esac
done

# --- Interactive mode if no title provided ---
if [ -z "$TITLE" ]; then
  echo -e "${CYAN}[opencode-kit ADR]${NC} Interactive mode"
  echo ""
  read -r -p "Title: " TITLE
  [ -z "$TITLE" ] && { echo -e "${RED}Title required${NC}"; exit 1; }
  read -r -p "Context (why this decision?): " CONTEXT
  read -r -p "Decision (what we decided): " DECISION
  read -r -p "Alternatives considered: " ALTERNATIVES
  read -r -p "Consequences (positive + negative): " CONSEQUENCES
fi

# --- Validate required fields ---
if [ -z "$TITLE" ]; then
  echo -e "${RED}❌ Title is required. Use: bash src/adr.sh \"Your Decision Title\"${NC}"
  exit 1
fi

# --- Compute next ADR ID ---
NEXT_ID=$(python3 -c "
import json
with open('$CONTRACT_FILE') as f: d = json.load(f)
log = d.get('decisions', {}).get('adr_log', [])
if not log:
  print('ADR-001')
else:
  last = max(int(entry.get('id','ADR-000').replace('ADR-','')) for entry in log)
  print(f'ADR-{last+1:03d}')
")

# --- Check for duplicate title ---
DUP=$(python3 -c "
import json
with open('$CONTRACT_FILE') as f: d = json.load(f)
log = d.get('decisions', {}).get('adr_log', [])
for entry in log:
  if entry.get('title','').lower().strip() == '$TITLE'.lower().strip():
    print(entry.get('id',''))
    break
" 2>/dev/null)
if [ -n "$DUP" ]; then
  echo -e "${YELLOW}⚠️  Duplicate title found: $DUP — '$TITLE'${NC}"
  echo "  Skipping. Update existing ADR instead."
  exit 0
fi

# --- Build ADR entry ---
ADR=$(python3 -c "
import json
entry = {
  'id': '$NEXT_ID',
  'date': '$(date +%Y-%m-%d)',
  'title': '$TITLE',
  'context': '$(echo "$CONTEXT" | python3 -c "import sys; print(sys.stdin.read().strip())" 2>/dev/null || echo "$CONTEXT")',
  'decision': '$(echo "$DECISION" | python3 -c "import sys; print(sys.stdin.read().strip())" 2>/dev/null || echo "$DECISION")',
  'alternatives': '$(echo "$ALTERNATIVES" | python3 -c "import sys; print(sys.stdin.read().strip())" 2>/dev/null || echo "$ALTERNATIVES")',
  'consequences': '$(echo "$CONSEQUENCES" | python3 -c "import sys; print(sys.stdin.read().strip())" 2>/dev/null || echo "$CONSEQUENCES")'
}
# Write temp file for the entry
with open('/tmp/opencode-adr-entry.json', 'w') as f:
  json.dump(entry, f, indent=2)
print('Entry written')
")

# --- Inject into contract.json ---
python3 -c "
import json

with open('$CONTRACT_FILE') as f:
  contract = json.load(f)

with open('/tmp/opencode-adr-entry.json') as f:
  entry = json.load(f)

if 'decisions' not in contract:
  contract['decisions'] = {}
if 'adr_log' not in contract['decisions']:
  contract['decisions']['adr_log'] = []

contract['decisions']['adr_log'].append(entry)

with open('$CONTRACT_FILE', 'w') as f:
  json.dump(contract, f, indent=2)

print(json.dumps(entry, indent=2))
"

echo ""
echo -e "${GREEN}[opencode-kit] ✅ ADR recorded: $NEXT_ID${NC}"
echo "  Title:        $TITLE"
echo "  File:         $CONTRACT_FILE"
echo "  Next:         Persist via: lean-ctx ctx_knowledge remember key orchestration-contract value \"\$(cat $CONTRACT_FILE)\""
