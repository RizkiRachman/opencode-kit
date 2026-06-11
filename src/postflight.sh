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

  # Extract all fields in one Python call and eval the result
  eval "$($PYTHON_CMD -c "
import json, sys
d = json.load(open('$POSTFLIGHT_DATA'))
fields = {
    'state': 'UNKNOWN', 'phase': 'none', 'score': '?',
    'prev_state': 'INIT', 'current_state': 'UNKNOWN',
    'phase_elapsed_s': '0', 'migrated': 'false',
    'contract_version': '?', 'phases_count': '0',
    'total_elapsed_s': '0', 'last_to_state': 'INIT'
}
for key, default in fields.items():
    val = str(d.get(key, default))
    # Escape single quotes for bash safety
    val = val.replace(\"'\", \"'\\\\''\")
    print(f'{key}=\"{val}\"')
" 2>/dev/null || echo "state=UNKNOWN phase=none score=? prev_state=INIT current_state=UNKNOWN phase_elapsed_s=0 migrated=false contract_version=? phases_count=0 total_elapsed_s=0 last_to_state=INIT")"

  # --- Echo status messages ---
  echo "  📊 Telemetry: $prev_state → $current_state (${phase_elapsed_s}s)"

  if [ "$migrated" = "true" ]; then
    echo "  🔄 Contract migrated to v${contract_version}"
  fi

  echo "  📝 Contract state: $state (phase: $phase, score: $score)"
  echo "  ✅ STATE.md synced"

  echo "  📈 Telemetry summary: ${phases_count} phases, ${total_elapsed_s}s total"
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
