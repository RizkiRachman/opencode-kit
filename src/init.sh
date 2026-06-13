#!/usr/bin/env bash
# opencode-kit init — scaffold orchestration framework
# Flow: check requirements → credentials → copy skills/agents → create opencode.json
# Usage: npx opencode-kit init [--force]
#   --force  Overwrite existing .opencode/ (backup + clean)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/platform.sh"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
FORCE=false
for arg in "$@"; do [ "$arg" = "--force" ] && FORCE=true; done
TIMESTAMP=$(date +%Y%m%d%H%M%S)
echo -e "${CYAN}[opencode-kit] Initializing in ${PWD}${NC}"

# ═══════════════════════════════════════════════════════════
# PHASE 1: CHECK REQUIREMENTS
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}[1/5] Checking requirements...${NC}"
deps_ok=true
for cmd in git node python3; do
  if command -v "$cmd" &>/dev/null; then
    echo "  ✅ $cmd: $(command -v "$cmd")"
  else
    echo "  ❌ $cmd: NOT FOUND"
    deps_ok=false
  fi
done
if command -v lean-ctx &>/dev/null; then
  echo "  ✅ lean-ctx: $(command -v "lean-ctx")"
else
  echo -e "  ${YELLOW}⚠️  lean-ctx: not found (optional, but recommended)${NC}"
  echo "  Install: https://github.com/ikieaneh/lean-ctx"
fi
if [ "$deps_ok" = false ]; then
  echo -e "\n${RED}❌ Missing requirements. Install and retry.${NC}"
  exit 1
fi
if ! git rev-parse --git-dir &>/dev/null; then
  git init -q && echo "  ✅ git initialized"
fi

# ═══════════════════════════════════════════════════════════
# PHASE 2: PREPARE CREDENTIALS
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}[2/5] Checking credentials...${NC}"
if [ -n "${FIRECRAWL_API_KEY:-}" ] || ([ -f ".env" ] && grep -q "FIRECRAWL_API_KEY" .env 2>/dev/null); then
  echo "  ✅ FIRECRAWL_API_KEY"
else
  echo -e "  ${YELLOW}⚠️  FIRECRAWL_API_KEY not set (web search limited)${NC}"
fi
if [ -n "${GITHUB_TOKEN:-}" ] || ([ -f ".env" ] && grep -q "GITHUB_TOKEN" .env 2>/dev/null); then
  echo "  ✅ GITHUB_TOKEN"
else
  echo -e "  ${YELLOW}⚠️  GITHUB_TOKEN not set (GitHub API limited)${NC}"
fi

# ═══════════════════════════════════════════════════════════
# PHASE 3: COPY SKILLS AND AGENTS
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}[3/5] Copying skills and agents...${NC}"
if [ -d ".opencode" ]; then
  if [ "$FORCE" = true ]; then
    cp -r ".opencode" ".opencode.bak.$TIMESTAMP"
    rm -rf ".opencode"
    echo "  ✅ Backup: .opencode.bak.$TIMESTAMP"
  else
    echo -e "  ${YELLOW}⚠️  .opencode/ exists. Use --force to re-scaffold.${NC}"
  fi
fi
mkdir -p .opencode/{orchestration,rules,agents,skills,src,templates}
# Agents
for agent in "$KIT_DIR"/agents/*.md; do
  cp "$agent" ".opencode/agents/$(basename "$agent")"
done
echo "  ✅ agents/ ($(ls .opencode/agents/*.md | wc -l | tr -d ' ') agents)"
# Skills
for skill_dir in "$KIT_DIR"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  if [ "$skill_name" != "__pycache__" ] && [ ! -d ".opencode/skills/$skill_name" ]; then
    cp -r "$skill_dir" ".opencode/skills/$skill_name"
  fi
done
echo "  ✅ skills/ ($(ls -d .opencode/skills/*/ 2>/dev/null | wc -l | tr -d ' ') skills)"
# Rules
for f in rules.json workflow-rules.json agent-rules.json learner-rules.json; do
  cp "$KIT_DIR/rules/$f" ".opencode/rules/$f"
done
echo "  ✅ rules/ (4 rule files)"
# Contract
python3 -c "
import json, os
for f in ['contract.json', 'rules/rules.json', 'rules/workflow-rules.json', 'rules/agent-rules.json', 'rules/learner-rules.json']:
    p = '.opencode/' + f
    if os.path.exists(p):
        d = json.load(open(p)); d.setdefault('_meta',{})['extends']='opencode-kit'
        json.dump(d, open(p,'w'), indent=2)
src='$KIT_DIR/contract.json'; dst='.opencode/orchestration/contract.json'
if os.path.exists(src):
    d = json.load(open(src)); d.setdefault('_meta',{})['extends']='opencode-kit'
    json.dump(d, open(dst,'w'), indent=2)
print('  ✅ _meta.extends set')
" 2>/dev/null
# Scripts
for script in verify.sh platform.sh merge-config.sh preflight.sh postflight.sh \
  doctor.sh status.sh scoring-pipeline.sh contract-lock.sh adoption-check.sh \
  audit-trail.sh contract-lint.sh checkpoint.sh diff.sh analytics.sh \
  adr.sh update.sh new-skill.sh global-config.sh telemetry.sh init.sh; do
  [ -f "$KIT_DIR/src/$script" ] && cp "$KIT_DIR/src/$script" ".opencode/src/$script" && chmod +x ".opencode/src/$script"
done
# Copy Python scripts
for pyscript in postflight.py; do
  [ -f "$KIT_DIR/src/$pyscript" ] && cp "$KIT_DIR/src/$pyscript" ".opencode/src/$pyscript" && chmod +x ".opencode/src/$pyscript"
done
echo "  ✅ src/ (scripts)"
# Git hooks
if [ -d "$KIT_DIR/.githooks" ]; then
  cp -r "$KIT_DIR/.githooks" .githooks && chmod +x .githooks/* && git config core.hooksPath .githooks
  echo "  ✅ .githooks/"
fi

# ═══════════════════════════════════════════════════════════
# PHASE 4: CREATE OR UPDATE OPENCODE.JSON
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}[4/5] Generating opencode.json...${NC}"
if [ -f "opencode.json" ]; then
  cp opencode.json "opencode.json.backup.$TIMESTAMP"
  bash "$KIT_DIR/src/generate-opencode-json.sh" "$KIT_DIR/opencode.json.template" "opencode.json"
  echo "  ✅ opencode.json merged (backup saved)"
else
  bash "$KIT_DIR/src/generate-opencode-json.sh" "$KIT_DIR/opencode.json.template" "opencode.json"
  echo "  ✅ opencode.json created"
fi

# ═══════════════════════════════════════════════════════════
# PHASE 5: VERIFY
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}[5/5] Verifying...${NC}"
echo "  Agents:  $(ls .opencode/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills:  $(ls -d .opencode/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  Rules:   $(ls .opencode/rules/*.json 2>/dev/null | wc -l | tr -d ' ')"
echo "  Scripts: $(ls .opencode/src/*.sh 2>/dev/null | wc -l | tr -d ' ')"
echo -e "\n${GREEN}✅ opencode-kit initialized${NC}"
echo ""
echo "  opencode.json has:"
echo "  • 15 agents (skills + tools, model from your global config)"
echo "  • 15 slash commands (/opencode-kit:*)"
echo "  • 5 MCPs (lean-ctx, gitnexus, context7, firecrawl, github)"
echo ""
echo "  Next:"
echo "  1. Set GOAL & SCOPE in .opencode/orchestration/contract.json"
echo "  2. Configure credentials (FIRECRAWL_API_KEY, GITHUB_TOKEN)"
echo "  3. Start opencode"