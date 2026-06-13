#!/usr/bin/env bash
# opencode-kit init — scaffold orchestration framework into target project
# Usage: npx opencode-kit init [--force] [--sample]
#   --force    Overwrite existing .opencode/ (backs up to .opencode.bak.<timestamp>)
#   --sample   Also create a sample opencode.json with @ikieaneh/opencode-kit plugin config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
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
    echo -e "${YELLOW}⚠️  .opencode/ already exists. Use --force to re-scaffold (backup + clean).${NC}"
    echo "  Skipping — existing .opencode/ preserved."
  fi
fi

# --- Scaffold directories ---
mkdir -p .opencode/orchestration .opencode/rules .opencode/agents .opencode/src .opencode/templates

# --- Copy templates ---
echo ""
echo "[opencode-kit] Scaffolding files..."

cp "$KIT_DIR/templates/contract.json" .opencode/orchestration/contract.json

# --- Seed session.model from opencode.json (if present) ---
python3 -c "
import json, os
contract_path = '.opencode/orchestration/contract.json'
config_path = 'opencode.json'
try:
    with open(contract_path) as f:
        contract = json.load(f)
except (FileNotFoundError, json.JSONDecodeError) as e:
    print(f'  ⚠️  Cannot read contract.json: {e}')
    exit(0)

model = ''
try:
    with open(config_path) as f:
        cfg = json.load(f)
    model = cfg.get('model', '')
except (FileNotFoundError, json.JSONDecodeError):
    model = ''

contract['session']['model'] = model
contract['session']['previous_model'] = ''
contract['session']['model_changed_at'] = ''
contract['session']['model_change_count'] = 0

with open(contract_path, 'w') as f:
    json.dump(contract, f, indent=2)
" && echo "  ✅ contract.json (session.model seeded)" || echo "  ⚠️  contract.json copied, model seed skipped"

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

  cp "$KIT_DIR/src/postflight.py" .opencode/src/postflight.py
  chmod +x .opencode/src/postflight.py
  echo "  ✅ postflight.py (executable)"

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

  cp "$KIT_DIR/src/status.sh" .opencode/src/status.sh
  chmod +x .opencode/src/status.sh
  echo "  ✅ status.sh (executable)"

  cp "$KIT_DIR/src/new-skill.sh" .opencode/src/new-skill.sh
  chmod +x .opencode/src/new-skill.sh
  echo "  ✅ new-skill.sh (executable)"

  cp "$KIT_DIR/src/analytics.sh" .opencode/src/analytics.sh
  chmod +x .opencode/src/analytics.sh
  echo "  ✅ analytics.sh (executable)"

  cp "$KIT_DIR/src/diff.sh" .opencode/src/diff.sh
  chmod +x .opencode/src/diff.sh
  echo "  ✅ diff.sh (executable)"

  # --- Copy agent templates (pre-flight gates) ---
  for agent in orchestrator planner task-manager code-reviewer learner fixer explorer librarian architect observer; do
    if [ -f "$KIT_DIR/templates/agents/$agent.md" ]; then
      cp "$KIT_DIR/templates/agents/$agent.md" ".opencode/agents/$agent.md"
      echo "  ✅ agents/$agent.md"
    fi
  done
fi

# --- Copy git hooks ---
if [ -d "$KIT_DIR/.githooks" ]; then
  cp -r "$KIT_DIR/.githooks" .githooks
  chmod +x .githooks/pre-commit .githooks/commit-msg
  echo "  ✅ .githooks/ (pre-commit, commit-msg)"
fi

# --- Git ignore .opencode/src (scripts are project-specific) ---
if [ -f ".gitignore" ]; then
  if ! grep -q ".opencode/src" .gitignore 2>/dev/null; then
    echo ".opencode/src/" >> .gitignore
  fi
fi

# --- Configure git hooks ---
if [ -d ".githooks" ]; then
  git config core.hooksPath .githooks
  echo "  ✅ Git hooks configured (.githooks/)"
fi

# --- Verify ---
echo ""
echo "[opencode-kit] Running verification..."
if "$KIT_DIR/src/verify.sh"; then
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  ✅ opencode-kit initialized (version: $(cat "$KIT_DIR/package.json" | grep '"version"' | head -1 | cut -d'"' -f4))${NC}"
  echo -e "${GREEN}========================================${NC}"
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
      "skills": ["orchestration-template", "dispatching-parallel-agents", "verification-before-completion", "using-superpowers"],
      "steps": 50,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "planner": {
      "model": "your-model",
      "skills": ["brainstorming", "writing-plans", "system-analyst"],
      "steps": 80,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "task-manager": {
      "model": "your-model",
      "skills": ["subagent-driven-development", "executing-plans", "test-driven-development"],
      "steps": 100,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "code-reviewer": {
      "model": "your-model",
      "skills": ["requesting-code-review", "receiving-code-review", "qa-expert", "security-expert"],
      "steps": 80,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "learner": {
      "model": "your-model",
      "skills": ["verification-before-completion", "qa-expert"],
      "steps": 40,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "fixer": {
      "model": "your-model",
      "skills": ["subagent-driven-development", "executing-plans", "using-git-worktrees"],
      "steps": 40,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "explorer": {
      "model": "your-model",
      "skills": ["humanizer", "firecrawl-search", "firecrawl-map"],
      "steps": 30,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "librarian": {
      "model": "your-model",
      "skills": ["humanizer", "firecrawl-search"],
      "steps": 30,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "architect": {
      "model": "your-model",
      "skills": ["simplify", "systematic-debugging", "system-analyst"],
      "steps": 60,
      "tools": { "bash": false, "lean-ctx_*": true }
    },
    "observer": {
      "model": "your-model",
      "skills": ["humanizer", "verification-before-completion", "systematic-debugging"],
      "steps": 30,
      "tools": { "bash": false, "lean-ctx_*": true }
    }
  },
  "command": {
    "opencode-kit:doctor": {
      "description": "Run opencode-kit project health checks",
      "prompt": "Run the opencode-kit doctor check. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/doctor.sh\") — then summarize the results for the user."
    },
    "opencode-kit:status": {
      "description": "Show opencode-kit project status",
      "prompt": "Show the opencode-kit project status. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/status.sh\") — then summarize the results for the user."
    },
    "opencode-kit:preflight": {
      "description": "Run opencode-kit pre-flight gate checks",
      "prompt": "Run the opencode-kit pre-flight gate. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/preflight.sh\") — report pass/fail for each check and any issues found."
    },
    "opencode-kit:score": {
      "description": "Run opencode-kit scoring pipeline on current contract",
      "prompt": "Run the opencode-kit scoring pipeline. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/scoring-pipeline.sh\") — report the score, verdict (PASS/RETRY/BLOCKED), and any deductions."
    },
    "opencode-kit:contract-lint": {
      "description": "Validate opencode-kit contract.json structure",
      "prompt": "Validate the opencode-kit contract. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/contract-lint.sh\") — report any validation errors or warnings."
    },
    "opencode-kit:checkpoint": {
      "description": "List opencode-kit checkpoints",
      "prompt": "List the current opencode-kit checkpoints. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/checkpoint.sh list\") — show the user all saved checkpoints."
    },
    "opencode-kit:audit": {
      "description": "Query the opencode-kit audit trail",
      "prompt": "Query the recent opencode-kit audit trail. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/audit-trail.sh query --limit 20\") — show the user recent audit events."
    },
    "opencode-kit:verify": {
      "description": "Verify opencode-kit project setup",
      "prompt": "Run the opencode-kit verification check. Execute: lean-ctx ctx_shell(command=\"bash .opencode/src/verify.sh\") — report which checks pass and which fail."
    }
  }
}
SAMPLEEOF
    echo "  ✅ Sample opencode.json created"
  fi
fi
