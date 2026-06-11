#!/usr/bin/env bash
# ⛔ opencode-kit preflight — MANDATORY enforcement gate
# Must run before any tool call. Exits with error if rules violated.
set -euo pipefail

CONTRACT_KEY="orchestration-contract"
RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "[opencode-kit] ⛔ Pre-flight check..."

# --- Check 1: contract.json exists on disk ---
if [ ! -f "$CONTRACT_FILE" ]; then
  echo -e "${RED}⛔ FAILED: $CONTRACT_FILE not found. Run 'opencode-kit init' first.${NC}"
  exit 1
fi
echo "  ✅ contract.json exists"

# --- Check 2: not on main ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo -e "${RED}⛔ FAILED: On '$BRANCH' branch. Create a feature branch first.${NC}"
  echo "  → git checkout -b feature/<YYYYMMDD>-<description>"
  exit 1
fi
echo "  ✅ Branch: $BRANCH (safe)"

# --- Check 3: lean-ctx reachable ---
if ! lean-ctx ctx_knowledge recall --query "$CONTRACT_KEY" &>/dev/null; then
  echo -e "${YELLOW}⚠️  WARNING: Cannot reach lean-ctx. Contract persistence will fail.${NC}"
  echo "  → Ensure lean-ctx MCP is configured"
else
  echo "  ✅ lean-ctx reachable"
fi

# --- Check 4: rules.json exists ---
if [ ! -f "$RULES_FILE" ]; then
  echo -e "${YELLOW}⚠️  WARNING: $RULES_FILE not found. Rules enforcement disabled.${NC}"
else
  echo "  ✅ rules.json found"
fi

echo "[opencode-kit] ✅ Pre-flight passed. Proceed."
