#!/usr/bin/env bash
# opencode-kit telemetry — view phase telemetry
# Usage: bash src/telemetry.sh [--json|--summary|--phases]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

TELEMETRY_DIR=".opencode/telemetry"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
      cat "$TELEMETRY_DIR/phases.jsonl" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        FROM=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('from','?'))" 2>/dev/null)
        TO=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('to','?'))" 2>/dev/null)
        MS=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('elapsed_ms',0))" 2>/dev/null)
        printf "  %-20s → %-20s  %5.1fs\n" "$FROM" "$TO" "$($PYTHON_CMD -c "print($MS/1000)" 2>/dev/null || echo "0.0")"
      done
    else
      echo -e "${YELLOW}No phase data yet.${NC}"
    fi
    ;;
  --summary|*)
    if [ -f "$TELEMETRY_DIR/summary.json" ]; then
      TOTAL_S=$($PYTHON_CMD -c "import json; d=json.load(open('$TELEMETRY_DIR/summary.json')); print(d.get('total_elapsed_s',0))" 2>/dev/null || echo "0")
      PHASES=$($PYTHON_CMD -c "import json; d=json.load(open('$TELEMETRY_DIR/summary.json')); print(len(d.get('phases_completed',[])))" 2>/dev/null || echo "0")
      echo "  Total elapsed: ${TOTAL_S}s"
      echo "  Phases completed: $PHASES"
      echo ""
      echo "  Latest phases:"
      tail -5 "$TELEMETRY_DIR/phases.jsonl" 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue
        TS=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('ts','?'))" 2>/dev/null | cut -dT -f2 | cut -d. -f1)
        FROM=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('from','?'))" 2>/dev/null)
        TO=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('to','?'))" 2>/dev/null)
        MS=$(echo "$line" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('elapsed_ms',0))" 2>/dev/null)
        echo "    $TS  $FROM → $TO  ($((MS/1000))s)"
      done
    else
      echo -e "${YELLOW}No telemetry data yet. Run a phase first.${NC}"
      echo "  Phases are recorded automatically by postflight.sh"
    fi
    ;;
esac
