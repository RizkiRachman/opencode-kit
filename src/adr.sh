#!/usr/bin/env bash
# opencode-kit ADR — auto-generate Architecture Decision Record
# Usage: bash src/adr.sh <title>
# Then enter context, decision, alternatives, consequences interactively.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Python check ---
if [ -z "$PYTHON_CMD" ]; then
  echo -e "${RED}❌ Python required but not found. Install python3.${NC}"
  exit 1
fi

CONTRACT_FILE=".opencode/orchestration/contract.json"

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
NEXT_ID=$(CONTRACT_FILE="$CONTRACT_FILE" $PYTHON_CMD -c "
import json, os
with open(os.environ['CONTRACT_FILE']) as f: d = json.load(f)
log = d.get('decisions', {}).get('adr_log', [])
if not log:
  print('ADR-001')
else:
  last = 0
  for entry in log:
    try:
      num = int(entry.get('id','ADR-000').replace('ADR-',''))
      if num > last: last = num
    except ValueError:
      continue
  print(f'ADR-{last+1:03d}')
")

# --- Check for duplicate title ---
DUP=$(CONTRACT_FILE="$CONTRACT_FILE" TITLE="$TITLE" $PYTHON_CMD -c "
import json, os
with open(os.environ['CONTRACT_FILE']) as f: d = json.load(f)
log = d.get('decisions', {}).get('adr_log', [])
search_title = os.environ.get('TITLE', '').lower().strip()
for entry in log:
  if entry.get('title','').lower().strip() == search_title:
    print(entry.get('id',''))
    break
" 2>/dev/null)
if [ -n "$DUP" ]; then
  echo -e "${YELLOW}⚠️  Duplicate title found: $DUP — '$TITLE'${NC}"
  echo "  Skipping. Update existing ADR instead."
  exit 0
fi

# --- Build ADR entry via Python (avoids shell injection) ---
ENTRY_FILE=$(mktemp /tmp/opencode-adr-entry-XXXXX.json)
trap 'rm -f "$ENTRY_FILE"' EXIT INT TERM

TITLE="$TITLE" CONTEXT="$CONTEXT" DECISION="$DECISION" ALTERNATIVES="$ALTERNATIVES" CONSEQUENCES="$CONSEQUENCES" NEXT_ID="$NEXT_ID" ENTRY_FILE="$ENTRY_FILE" $PYTHON_CMD -c "
import json, os
from datetime import date

entry = {
    'id': os.environ['NEXT_ID'],
    'date': date.today().isoformat(),
    'title': os.environ.get('TITLE', ''),
    'context': os.environ.get('CONTEXT', ''),
    'decision': os.environ.get('DECISION', ''),
    'alternatives': os.environ.get('ALTERNATIVES', ''),
    'consequences': os.environ.get('CONSEQUENCES', '')
}

with open(os.environ['ENTRY_FILE'], 'w') as f:
    json.dump(entry, f, indent=2)
print('Entry written')
"

# --- Inject into contract.json ---
CONTRACT_FILE="$CONTRACT_FILE" ENTRY_FILE="$ENTRY_FILE" $PYTHON_CMD -c "
import json, os

with open(os.environ['CONTRACT_FILE']) as f:
  contract = json.load(f)

with open(os.environ['ENTRY_FILE']) as f:
  entry = json.load(f)

if 'decisions' not in contract:
  contract['decisions'] = {}
if 'adr_log' not in contract['decisions']:
  contract['decisions']['adr_log'] = []

contract['decisions']['adr_log'].append(entry)

with open(os.environ['CONTRACT_FILE'], 'w') as f:
  json.dump(contract, f, indent=2)

print(json.dumps(entry, indent=2))
"

rm -f "$ENTRY_FILE"

echo ""
echo -e "${GREEN}[opencode-kit] ✅ ADR recorded: $NEXT_ID${NC}"
echo "  Title:        $TITLE"
echo "  File:         $CONTRACT_FILE"
echo "  Next:         Persist via: lean-ctx ctx_knowledge remember key orchestration-contract value \"\$(cat $CONTRACT_FILE)\""
