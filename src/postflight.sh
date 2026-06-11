#!/usr/bin/env bash
# opencode-kit postflight — persist contract + update STATE.md
# Run after every delegation or phase change.
set -euo pipefail

CONTRACT_KEY="orchestration-contract"
CONTRACT_FILE=".opencode/orchestration/contract.json"
STATE_FILE="STATE.md"

echo "[opencode-kit] Post-flight: persisting state..."

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
  STATE=$(echo "$CURRENT_CONTRACT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
  PHASE=$(echo "$CURRENT_CONTRACT" | python3 -c "import sys,json; d=json.load(sys.stdin); r=d.get('retry',{}); print(r.get('current_phase','none'))" 2>/dev/null || echo "none")
  echo "  📝 Contract state: $STATE (phase: $PHASE)"
fi

# --- Step 4: Save ctx_session ---
lean-ctx ctx_session save 2>/dev/null && \
  echo "  ✅ Session saved" || \
  echo "  ⚠️  ctx_session save skipped (not available)"

echo "[opencode-kit] ✅ Post-flight complete."
