#!/usr/bin/env bash
# opencode-kit postflight — persist contract + telemetry + update STATE.md
# Run after every delegation or phase change.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

CONTRACT_KEY="orchestration-contract"
CONTRACT_FILE=".opencode/orchestration/contract.json"
STATE_FILE="STATE.md"
TELEMETRY_DIR=".opencode/telemetry"
STATE_BACKUP_DIR=".opencode/state"
TEMPLATE_FILE=".opencode/templates/contract.json"

mkdir -p "$TELEMETRY_DIR" "$STATE_BACKUP_DIR"

echo "[opencode-kit] Post-flight: persisting state..."

# --- Resolve contract: try lean-ctx first, fall back to file ---
LEAN_CTX_CONTRACT=$(lean-ctx ctx_knowledge recall --query "$CONTRACT_KEY" 2>/dev/null || true)
if [ -n "$LEAN_CTX_CONTRACT" ]; then
  echo "$LEAN_CTX_CONTRACT" > "$CONTRACT_FILE"
fi

# --- Single Python call: batch all contract/telemetry/STATE.md operations ---
PYTHON_OUTPUT=""
STATE=""
if [ -n "$PYTHON_CMD" ]; then
  PYTHON_OUTPUT=$($PYTHON_CMD "$SCRIPT_DIR/postflight.py" \
    "$CONTRACT_FILE" "$TELEMETRY_DIR" "$STATE_FILE" \
    "$STATE_BACKUP_DIR" "$TEMPLATE_FILE" \
  )

  # Write Python output to temp file for robust JSON field extraction
  POSTFLIGHT_DATA=$(mktemp /tmp/opencode-postflight-XXXXX.json)
  echo "$PYTHON_OUTPUT" > "$POSTFLIGHT_DATA"
  trap 'rm -f "$POSTFLIGHT_DATA"' EXIT INT TERM

  STATE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  PHASE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('phase','none'))" 2>/dev/null || echo "none")
  SCORE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('score','?'))" 2>/dev/null || echo "?")
  PREV_STATE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('prev_state','INIT'))" 2>/dev/null || echo "INIT")
  CURRENT_STATE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('current_state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  ELAPSED_S=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('phase_elapsed_s','0'))" 2>/dev/null || echo "0")
  MIGRATED=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('migrated','false'))" 2>/dev/null || echo "false")
  CONTRACT_VER=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('contract_version','?'))" 2>/dev/null || echo "?")
  PHASES_COUNT=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('phases_count','0'))" 2>/dev/null || echo "0")
  TOTAL_ELAPSED_S=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('total_elapsed_s','0'))" 2>/dev/null || echo "0")
  LAST_TO_STATE=$($PYTHON_CMD -c "import json; d=json.load(open('$POSTFLIGHT_DATA')); print(d.get('last_to_state','INIT'))" 2>/dev/null || echo "INIT")

  # --- Echo status messages ---
  echo "  📊 Telemetry: $PREV_STATE → $CURRENT_STATE (${ELAPSED_S}s)"

  if [ "$MIGRATED" = "true" ]; then
    echo "  🔄 Contract migrated to v${CONTRACT_VER}"
  fi

  echo "  📝 Contract state: $STATE (phase: $PHASE, score: $SCORE)"
  echo "  ✅ STATE.md synced"

  echo "  📈 Telemetry summary: ${PHASES_COUNT} phases, ${TOTAL_ELAPSED_S}s total"
else
  echo "  ⚠️  Python not available, skipping postflight processing"
fi

# --- Persist to lean-ctx ---
if [ -n "$PYTHON_CMD" ] && [ -f "$CONTRACT_FILE" ]; then
  CONTRACT_JSON=$(cat "$CONTRACT_FILE")
  if lean-ctx ctx_knowledge remember \
    category architecture \
    key "$CONTRACT_KEY" \
    value "$CONTRACT_JSON" 2>/dev/null; then
    echo "  ✅ Contract persisted to lean-ctx"
  fi
fi

# File fallback always written by Python script to $STATE_BACKUP_DIR/contract.json
echo "  ✅ Contract persisted to file: $STATE_BACKUP_DIR/contract.json"

# --- Save ctx_session ---
lean-ctx ctx_session save 2>/dev/null && \
  echo "  ✅ Session saved" || \
  echo "  ⚠️  ctx_session save skipped (not available)"

echo "[opencode-kit] ✅ Post-flight complete."
