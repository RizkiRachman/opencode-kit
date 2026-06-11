#!/usr/bin/env bash
# opencode-kit postflight — persist contract + telemetry + update STATE.md
# Run after every delegation or phase change.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

CONTRACT_KEY="orchestration-contract"
CONTRACT_FILE=".opencode/orchestration/contract.json"
STATE_FILE="STATE.md"
TELEMETRY_DIR=".opencode/telemetry"
START_TIME_FILE=".opencode/telemetry/.phase_start"

echo "[opencode-kit] Post-flight: persisting state..."

# --- Telemetry: record phase completion ---
mkdir -p "$TELEMETRY_DIR"
PHASE_START=$(cat "$START_TIME_FILE" 2>/dev/null || echo "")
if [ -n "$PHASE_START" ]; then
  PHASE_ELAPSED=$(( $(date +%s) - PHASE_START ))
  # Read current state from contract
  if [ -f "$CONTRACT_FILE" ]; then
    CURRENT_STATE=$($PYTHON_CMD -c "
import json
with open('$CONTRACT_FILE') as f: d=json.load(f)
print(d.get('state','UNKNOWN'))
" 2>/dev/null || echo "UNKNOWN")
    PREV_STATE=""
    [ -f "$TELEMETRY_DIR/phases.jsonl" ] && PREV_STATE=$(tail -1 "$TELEMETRY_DIR/phases.jsonl" 2>/dev/null | $PYTHON_CMD -c "import sys,json; print(json.load(sys.stdin).get('to','INIT'))" 2>/dev/null || echo "INIT")
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"from\":\"$PREV_STATE\",\"to\":\"$CURRENT_STATE\",\"elapsed_ms\":$((PHASE_ELAPSED * 1000))}" >> "$TELEMETRY_DIR/phases.jsonl"
    echo "  📊 Telemetry: $PREV_STATE → $CURRENT_STATE (${PHASE_ELAPSED}s)"
  fi
  rm -f "$START_TIME_FILE"
fi

# --- Step 1: Re-read contract from lean-ctx (the source of truth) ---
CURRENT_CONTRACT=$(lean-ctx ctx_knowledge recall --query "$CONTRACT_KEY" 2>/dev/null || cat "$CONTRACT_FILE")

# --- Step 2: Write back to lean-ctx ---
lean-ctx ctx_knowledge remember \
  category architecture \
  key "$CONTRACT_KEY" \
  value "$CURRENT_CONTRACT" 2>/dev/null && \
  echo "  ✅ Contract persisted to lean-ctx" || \
  echo "  ⚠️  lean-ctx persist failed"

# --- Step 3: Update STATE.md if it exists ---
if [ -f "$STATE_FILE" ]; then
  STATE=$(echo "$CURRENT_CONTRACT" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  PHASE=$(echo "$CURRENT_CONTRACT" | $PYTHON_CMD -c "import sys,json; d=json.load(sys.stdin); r=d.get('retry',{}); print(r.get('current_phase','none'))" 2>/dev/null || echo "none")
  echo "  📝 Contract state: $STATE (phase: $PHASE)"
fi

# --- Step 4: Save ctx_session ---
lean-ctx ctx_session save 2>/dev/null && \
  echo "  ✅ Session saved" || \
  echo "  ⚠️  ctx_session save skipped (not available)"

# --- Step 5: Update telemetry summary ---
if [ -f "$TELEMETRY_DIR/phases.jsonl" ] && [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json
total_ms = 0
agents = set()
phases = []
with open('$TELEMETRY_DIR/phases.jsonl') as f:
  for line in f:
    line=line.strip()
    if not line: continue
    try:
      entry=json.loads(line)
      total_ms+=entry.get('elapsed_ms',0)
      phases.append(entry.get('to',''))
    except: pass

summary = {
  'phases_completed': phases,
  'total_elapsed_ms': total_ms,
  'total_elapsed_s': round(total_ms/1000, 1),
  'updated_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$TELEMETRY_DIR/summary.json', 'w') as f:
  json.dump(summary, f, indent=2)
print(f'  📈 Telemetry summary: {len(phases)} phases, {total_ms/1000:.0f}s total')
" 2>/dev/null || true
fi

echo "[opencode-kit] ✅ Post-flight complete."
