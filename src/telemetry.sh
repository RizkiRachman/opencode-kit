#!/usr/bin/env bash
# opencode-kit telemetry — view phase telemetry
# Usage: bash src/telemetry.sh [--json|--summary|--phases]
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

TELEMETRY_DIR=".opencode/telemetry"
CONTRACT_FILE=".opencode/orchestration/contract.json"

MODE="${1:-summary}"

echo -e "${CYAN}[opencode-kit] 📊 Telemetry${NC}"
echo ""

case "$MODE" in
  --json)
    if [ -f "$TELEMETRY_DIR/summary.json" ]; then
      cat "$TELEMETRY_DIR/summary.json"
    else
      echo -e "${YELLOW}No telemetry data yet. Run a phase first.${NC}"
    fi
    ;;
  --phases)
    if [ -f "$TELEMETRY_DIR/phases.jsonl" ]; then
      echo "Phase transitions:"
      $PYTHON_CMD -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    d = json.loads(line)
    from_ = d.get('from', '?')
    to_ = d.get('to', '?')
    ms = d.get('elapsed_ms', 0)
    print(f'  {from_:20s} → {to_:20s}  {ms/1000:5.1f}s')
" < "$TELEMETRY_DIR/phases.jsonl" 2>/dev/null || echo -e "${YELLOW}Could not parse phase data${NC}"
    else
      echo -e "${YELLOW}No phase data yet.${NC}"
    fi
    ;;
  --summary|*)
    if [ -f "$TELEMETRY_DIR/summary.json" ]; then
      read -r TOTAL_S PHASES < <(TELEMETRY_DIR="$TELEMETRY_DIR" $PYTHON_CMD -c "
import json, os
d = json.load(open(os.environ['TELEMETRY_DIR'] + '/summary.json'))
print(d.get('total_elapsed_s', 0))
print(len(d.get('phases_completed', [])))
" 2>/dev/null || echo -e "0\n0")
      echo "  Total elapsed: ${TOTAL_S}s"
      echo "  Phases completed: $PHASES"
      echo ""
      echo "  Latest phases:"
      tail -5 "$TELEMETRY_DIR/phases.jsonl" 2>/dev/null | $PYTHON_CMD -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    d = json.loads(line)
    ts = d.get('ts', '?')
    if ts != '?':
        ts = ts.split('T')[1].split('.')[0] if 'T' in ts else ts
    from_ = d.get('from', '?')
    to_ = d.get('to', '?')
    ms = d.get('elapsed_ms', 0)
    print(f'    {ts}  {from_} → {to_}  ({ms//1000}s)')
" 2>/dev/null || echo -e "${YELLOW}Could not parse phase data${NC}"
    else
      echo -e "${YELLOW}No telemetry data yet. Run a phase first.${NC}"
      echo "  Phases are recorded automatically by postflight.sh"
    fi
    ;;
esac
