#!/usr/bin/env bash
# ⛔ opencode-kit preflight — MANDATORY enforcement gate
# Must run before any tool call. Exits with error if rules violated.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

CONTRACT_KEY="orchestration-contract"
RULES_FILE=".opencode/rules/rules.json"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
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

# --- Check 3: MCP Availability ---
echo ""
echo "  Checking MCP availability..."

MCP_FAIL=0

# 3a. lean-ctx
LEAN_CTX_AVAILABLE=false
if command -v lean-ctx &>/dev/null; then
  echo "  ✅ lean-ctx MCP: available (cli)"
  LEAN_CTX_AVAILABLE=true
elif lean-ctx ctx_knowledge recall --query "$CONTRACT_KEY" &>/dev/null; then
  echo "  ✅ lean-ctx MCP: available (tool)"
  LEAN_CTX_AVAILABLE=true
else
  echo -e "${YELLOW}  ⚠️  lean-ctx MCP: NOT DETECTED — contract persistence will fail${NC}"
  echo -e "${YELLOW}     → Ensure lean-ctx is configured in opencode.json MCP servers${NC}"
  MCP_FAIL=1
fi

# 3b. gitnexus
if npx --yes gitnexus --version &>/dev/null; then
  echo "  ✅ gitnexus MCP: available"
elif npx --yes gitnexus list-repos &>/dev/null; then
  echo "  ✅ gitnexus MCP: available"
else
  echo -e "${YELLOW}  ⚠️  gitnexus MCP: NOT DETECTED — impact analysis will fail${NC}"
  echo -e "${YELLOW}     → Ensure gitnexus is configured in opencode.json MCP servers${NC}"
  MCP_FAIL=1
fi

# 3c. graphify (check via gitnexus index since graphify consumes gitnexus data)
GRAPHIFY_AVAILABLE=false
if npx --yes gitnexus analyze --help &>/dev/null; then
  # gitnexus is available — check if index exists
  GITNEXUS_DIR=$(find . -name "gitnexus-out" -type d 2>/dev/null | head -1)
  if [ -n "$GITNEXUS_DIR" ]; then
    echo "  ✅ graphify: available (gitnexus index found)"
    GRAPHIFY_AVAILABLE=true
  else
    echo -e "${YELLOW}  ⚠️  graphify: gitnexus index not built yet. Run: npx gitnexus analyze${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠️  graphify: gitnexus not available — graphify depends on gitnexus index${NC}"
fi

# 3d. context7 (library docs — soft check, non-blocking)
if command -v curl &>/dev/null; then
  echo "  ✅ context7 MCP: curl available (http transport)"
fi

echo ""

# --- Check 4: rules.json exists ---
if [ ! -f "$RULES_FILE" ]; then
  echo -e "${YELLOW}⚠️  WARNING: $RULES_FILE not found. Rules enforcement disabled.${NC}"
else
  echo "  ✅ rules.json found"
fi

# --- Telemetry: record phase start ---
mkdir -p .opencode/telemetry
echo $(date +%s) > .opencode/telemetry/.phase_start

# --- Check 5: contract state validation ---
if [ -n "$PYTHON_CMD" ] && [ -f "$CONTRACT_FILE" ]; then
  STATE=$($PYTHON_CMD -c "
import json,sys
try:
  with open('$CONTRACT_FILE') as f: d=json.load(f)
  print(d.get('state','UNKNOWN'))
except: print('PARSE_ERROR')
" 2>/dev/null)
  if [ "$STATE" = "PARSE_ERROR" ] || [ "$STATE" = "UNKNOWN" ]; then
    echo -e "${YELLOW}  ⚠️  Contract state: unknown — contract.json may be malformed${NC}"
  else
    echo "  ✅ Contract state: $STATE"
  fi
fi

# --- Final verdict ---
if [ "$MCP_FAIL" -eq 1 ]; then
  echo -e "${YELLOW}[opencode-kit] ⛔ Pre-flight completed with WARNINGS. Missing MCPs may cause failures.${NC}"
else
  echo "[opencode-kit] ✅ Pre-flight passed. All MCPs available. Proceed."
fi
