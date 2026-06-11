#!/usr/bin/env bash
# opencode-kit init — scaffold orchestration framework into target project
# Usage: npx opencode-kit init [--force] [--sample]
#   --force    Overwrite existing .opencode/ (backs up to .opencode.bak.<timestamp>)
#   --sample   Also create a sample opencode.json with @ikieaneh/opencode-kit plugin config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"
. "$SCRIPT_DIR/global-config.sh"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

FORCE=false
SAMPLE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --sample) SAMPLE=true ;;
  esac
done
TARGET_DIR="${PWD}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "[opencode-kit] 🚀 Initializing orchestration framework in $TARGET_DIR"

# --- Dependency check ---
echo ""
echo "[opencode-kit] Checking dependencies..."

deps_ok=0
for cmd in git node; do
  if command -v "$cmd" &>/dev/null; then
    echo "  ✅ $cmd: $(command -v $cmd)"
  else
    echo "  ❌ $cmd: NOT FOUND — install $cmd first"
    deps_ok=1
  fi
done

# Check lean-ctx via MCP key (soft check — warn, don't block)
if command -v lean-ctx &>/dev/null; then
  echo "  ✅ lean-ctx available"
else
  echo "  ⚠️  lean-ctx not detected — ensure it's configured in MCP"
fi

if [ "$deps_ok" -eq 1 ]; then
  echo -e "${RED}❌ Missing dependencies. Install them and retry.${NC}"
  exit 1
fi

# --- Git check ---
if ! git rev-parse --git-dir &>/dev/null; then
  echo ""
  echo "[opencode-kit] Not a git repository. Initializing..."
  git init
  echo "  ✅ git initialized"
fi

# --- Detect plugin mode ---
PLUGIN_MODE=false
if is_plugin_active; then
  PLUGIN_MODE=true
  echo ""
  echo -e "${CYAN}[opencode-kit] Plugin detected — scaffolding project data only${NC}"
fi

# --- Handle existing .opencode/ ---
if [ -d ".opencode" ]; then
  if [ "$FORCE" = true ]; then
    BACKUP=".opencode.bak.$TIMESTAMP"
    echo ""
    echo -e "${YELLOW}⚠️  --force: Backing up existing .opencode/ to $BACKUP${NC}"
    cp -r ".opencode" "$BACKUP"
    rm -rf ".opencode"
    echo "  ✅ Backed up to $BACKUP"
  else
    echo ""
    echo -e "${YELLOW}⚠️  .opencode/ already exists. Use --force to overwrite (backup + clean scaffold).${NC}"
    echo "  Missing files will be added. Existing files will NOT be overwritten."
  fi
fi

# --- Scaffold directories ---
mkdir -p .opencode/orchestration .opencode/rules .opencode/agents .opencode/src

# --- Copy templates ---
echo ""
echo "[opencode-kit] Scaffolding files..."

cp "$KIT_DIR/templates/contract.json" .opencode/orchestration/contract.json
echo "  ✅ contract.json"

cp "$KIT_DIR/templates/superpowers-contract.json" .opencode/templates/superpowers-contract.json
echo "  ✅ superpowers-contract.json"

cp "$KIT_DIR/rules/rules.json" .opencode/rules/rules.json
echo "  ✅ rules.json"

cp "$KIT_DIR/src/verify.sh" .opencode/src/verify.sh
chmod +x .opencode/src/verify.sh
echo "  ✅ verify.sh (executable)"

cp "$KIT_DIR/src/platform.sh" .opencode/src/platform.sh
chmod +x .opencode/src/platform.sh
echo "  ✅ platform.sh (executable)"

# Plugin-specific: scripts that exist locally for CLI access
if [ "$PLUGIN_MODE" = false ]; then
  # Non-plugin mode: copy all shell scripts
  cp "$KIT_DIR/rules/validation.sh" .opencode/rules/validation.sh
  chmod +x .opencode/rules/validation.sh
  echo "  ✅ rules/validation.sh"

  cp "$KIT_DIR/src/preflight.sh" .opencode/src/preflight.sh
  chmod +x .opencode/src/preflight.sh
  echo "  ✅ preflight.sh (executable)"

  cp "$KIT_DIR/src/postflight.sh" .opencode/src/postflight.sh
  chmod +x .opencode/src/postflight.sh
  echo "  ✅ postflight.sh (executable)"

  cp "$KIT_DIR/src/update.sh" .opencode/src/update.sh
  chmod +x .opencode/src/update.sh
  echo "  ✅ update.sh (executable)"

  cp "$KIT_DIR/src/adr.sh" .opencode/src/adr.sh
  chmod +x .opencode/src/adr.sh
  echo "  ✅ adr.sh (executable)"

  cp "$KIT_DIR/src/telemetry.sh" .opencode/src/telemetry.sh
  chmod +x .opencode/src/telemetry.sh
  echo "  ✅ telemetry.sh (executable)"

  cp "$KIT_DIR/src/doctor.sh" .opencode/src/doctor.sh
  chmod +x .opencode/src/doctor.sh
  echo "  ✅ doctor.sh (executable)"

  # --- Copy agent templates (pre-flight gates) ---
  for agent in orchestrator planner task-manager code-reviewer learner fixer; do
    if [ -f "$KIT_DIR/templates/agents/$agent.md" ]; then
      cp "$KIT_DIR/templates/agents/$agent.md" ".opencode/agents/$agent.md"
      echo "  ✅ agents/$agent.md"
    fi
  done
fi

# --- Git ignore .opencode/src (scripts are project-specific) ---
if [ -f ".gitignore" ]; then
  if ! grep -q ".opencode/src" .gitignore 2>/dev/null; then
    echo ".opencode/src/" >> .gitignore
  fi
fi

# --- Verify ---
echo ""
echo "[opencode-kit] Running verification..."
if "$KIT_DIR/src/verify.sh"; then
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  ✅ opencode-kit v0.5.0 initialized${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Next steps:"
  echo "  1. Set GOAL & SCOPE in .opencode/orchestration/contract.json"
  echo "  2. Set your project rules in .opencode/rules/rules.json"
  echo "  3. Read AGENTS.md for writing conventions"
  echo "  4. Start with: Load contract → Plan → Execute → Review"
else
  echo -e "${RED}❌ Verification failed. Check errors above.${NC}"
  exit 1
fi

# --- Sample opencode.json ---
if [ "$SAMPLE" = true ]; then
  if [ -f "opencode.json" ]; then
    echo -e "${YELLOW}  ⚠️  opencode.json already exists. Skipping sample.${NC}"
  else
    cat > opencode.json << 'SAMPLEEOF'
{
  "model": "your-model",
  "plugin": [
    "@ikieaneh/opencode-kit",
    "superpowers"
  ],
  "agent": {
    "orchestrator": {
      "model": "your-model",
      "skills": ["orchestration-template", "scoring-pipeline", "verification-before-completion"],
      "steps": 50
    },
    "planner": {
      "model": "your-model",
      "skills": ["brainstorming", "writing-plans", "system-analyst"],
      "steps": 80
    },
    "task-manager": {
      "model": "your-model",
      "skills": ["subagent-driven-development", "executing-plans", "test-driven-development"],
      "steps": 100
    },
    "code-reviewer": {
      "model": "your-model",
      "skills": ["qa-expert", "security-expert"],
      "steps": 80
    }
  }
}
SAMPLEEOF
    echo "  ✅ Sample opencode.json created"
  fi
fi
