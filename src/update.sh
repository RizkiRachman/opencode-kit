#!/usr/bin/env bash
# opencode-kit update — pull latest templates and scripts from GitHub
# Preserves existing contract.json state (goal, scope, decisions).
# Usage: bash src/update.sh [--dry-run] [--version <tag>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
VERSION="main"
REPO_URL="https://github.com/RizkiRachman/opencode-kit.git"

# --- Parse args ---
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --version) VERSION="$2"; shift 2 ;;
    -v) VERSION="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown: $1${NC}"; exit 1 ;;
  esac
done

echo -e "${CYAN}[opencode-kit] 🔄 Update check${NC}"
echo "  Current dir: $PWD"
echo "  Source:      $REPO_URL (branch: $VERSION)"
echo "  Dry run:     $DRY_RUN"
echo ""

# --- Check we're in an opencode-kit project ---
if [ ! -d ".opencode" ]; then
  echo -e "${RED}❌ No .opencode/ directory found. Are you in an opencode-kit project?${NC}"
  exit 1
fi

# --- Clone latest to temp ---
TEMP_DIR=$(mktemp -d /tmp/opencode-kit-XXXXX)
echo "  Cloning latest version to $TEMP_DIR..."

if ! git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
  echo -e "${RED}❌ Failed to clone $REPO_URL (branch: $VERSION)${NC}"
  rm -rf "$TEMP_DIR"
  exit 1
fi
echo "  ✅ Cloned"

# --- Read versions ---
CURRENT_VERSION=""
if [ -f ".opencode/orchestration/contract.json" ]; then
  CURRENT_VERSION=$($PYTHON_CMD -c "
import json
with open('.opencode/orchestration/contract.json') as f:
  d=json.load(f)
print(d.get('contract_version', 'unknown'))
" 2>/dev/null || echo "unknown")
fi

LATEST_VERSION=$($PYTHON_CMD -c "
import json
with open('$TEMP_DIR/templates/contract.json') as f:
  d=json.load(f)
print(d.get('contract_version', 'unknown'))
" 2>/dev/null || echo "unknown")

echo "  Current version: $CURRENT_VERSION"
echo "  Latest version:  $LATEST_VERSION"
echo ""

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && [ "$VERSION" = "main" ]; then
  echo -e "${GREEN}✅ Already up to date (v$CURRENT_VERSION)${NC}"
  rm -rf "$TEMP_DIR"
  exit 0
fi

# --- Backup contract state ---
echo "  Backing up contract state..."
STATE_BACKUP=$(mktemp /tmp/opencode-contract-state-XXXXX.json)
$PYTHON_CMD -c "
import json
with open('.opencode/orchestration/contract.json') as f:
  d = json.load(f)
# Extract only the state fields to preserve
state = {
  'requirements': d.get('requirements', {}),
  'scope': d.get('scope', {}),
  'decisions': d.get('decisions', {}),
  'governance': d.get('governance', {}),
  'metrics': d.get('metrics', {}),
  'lessons_learned': d.get('lessons_learned', []),
  'retry': d.get('retry', {}),
  'score': d.get('score', {}),
  'outputs': d.get('outputs', {})
}
with open('$STATE_BACKUP', 'w') as f:
  json.dump(state, f, indent=2)
" 2>/dev/null || echo "  ⚠️  Could not backup contract state"
echo "  ✅ State backed up"

# --- Files to update ---
echo ""
echo "  Files to update:"
UPDATES=0

update_file() {
  local src="$1"
  local dst="$2"
  local label="$3"
  if [ -f "$src" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY-RUN] Would update: $label"
    else
      cp "$src" "$dst"
      chmod +x "$dst" 2>/dev/null || true
      echo "  ✅ Updated: $label"
    fi
    UPDATES=$((UPDATES + 1))
  else
    echo "  ⚠️  Source not found: $src"
  fi
}

# Update scripts
for script in preflight.sh postflight.sh verify.sh adr.sh platform.sh; do
  update_file "$TEMP_DIR/src/$script" ".opencode/src/$script" "src/$script"
done

# Update init.sh (for future --force re-inits)
update_file "$TEMP_DIR/src/init.sh" ".opencode/src/init.sh" "src/init.sh"

# Update update.sh itself
update_file "$TEMP_DIR/src/update.sh" ".opencode/src/update.sh" "src/update.sh"

# Update rules
update_file "$TEMP_DIR/rules/rules.json" ".opencode/rules/rules.json" "rules/rules.json"
update_file "$TEMP_DIR/rules/validation.sh" ".opencode/rules/validation.sh" "rules/validation.sh"

# Update agent templates (but NOT contract.json — preserve state)
for agent in orchestrator planner task-manager code-reviewer learner fixer; do
  update_file "$TEMP_DIR/templates/agents/$agent.md" ".opencode/agents/$agent.md" "agents/$agent.md"
done

# Update superpowers contract template
update_file "$TEMP_DIR/templates/superpowers-contract.json" ".opencode/templates/superpowers-contract.json" "superpowers-contract.json"

# --- Restore contract state ---
if [ "$DRY_RUN" = false ] && [ -f "$STATE_BACKUP" ]; then
  $PYTHON_CMD -c "
import json
with open('.opencode/orchestration/contract.json') as f:
  contract = json.load(f)
with open('$STATE_BACKUP') as f:
  state = json.load(f)
# Merge preserved state back into new contract
for key, val in state.items():
  if val:  # only overwrite if backup has data
    contract[key] = val
# Update contract_version to latest
contract['contract_version'] = '$LATEST_VERSION'
with open('.opencode/orchestration/contract.json', 'w') as f:
  json.dump(contract, f, indent=2)
" 2>/dev/null && echo "  ✅ Contract state restored" || echo "  ⚠️  Contract state restore failed"
fi

# --- Cleanup ---
rm -rf "$TEMP_DIR" "$STATE_BACKUP"

# --- Summary ---
echo ""
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[opencode-kit] 🔄 Dry run complete. $UPDATES files would be updated.${NC}"
else
  echo -e "${GREEN}[opencode-kit] ✅ Update complete. $UPDATES files updated.${NC}"
  echo "  Run .opencode/src/verify.sh to verify installation."
fi
