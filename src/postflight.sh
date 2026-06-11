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

  # Single Python parse call: extract all values as pipe-delimited string
  IFS='|' read -r STATE PHASE SCORE PREV_STATE CURRENT_STATE ELAPSED_S MIGRATED CONTRACT_VER PHASES_COUNT TOTAL_ELAPSED_S LAST_TO_STATE <<< \
    "$(echo "$PYTHON_OUTPUT" | $PYTHON_CMD -c "
import sys, json
d = json.load(sys.stdin)
print('|'.join([str(d.get(k, '')) for k in [
    'state', 'phase', 'score', 'prev_state', 'current_state',
    'phase_elapsed_s', 'migrated', 'contract_version',
    'phases_count', 'total_elapsed_s', 'last_to_state'
]]))
" 2>/dev/null || echo "UNKNOWN|none|?|INIT|UNKNOWN|0|false|?|0|0|INIT")"

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
