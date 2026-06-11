#!/usr/bin/env bash
# opencode-kit status — pretty terminal dashboard
# Usage: bash src/status.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

CONTRACT_FILE=".opencode/orchestration/contract.json"
RULES_FILE=".opencode/rules/rules.json"
TELEMETRY_DIR=".opencode/telemetry"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║        opencode-kit Dashboard            ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# === Contract State ===
if [ -f "$CONTRACT_FILE" ] && [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json
with open('$CONTRACT_FILE') as f:
    c = json.load(f)

state = c.get('state', 'UNKNOWN')
ver = c.get('contract_version', '?')
goal = c.get('requirements', {}).get('goal', 'Not set')
phases = c.get('metrics', {}).get('phases_completed', [])
score = c.get('score', {}).get('combined', 0)
verdict = c.get('score', {}).get('verdict', 'PENDING')
adrs = len(c.get('decisions', {}).get('adr_log', []))
ext_skills = c.get('governance', {}).get('extension_skills', [])

# State color
state_colors = {
    'INIT': '\033[0;36m',
    'PLAN': '\033[1;33m',
    'PLAN_SCORED': '\033[1;33m',
    'EXECUTE': '\033[0;32m',
    'EXECUTE_SCORED': '\033[0;32m',
    'REVIEW': '\033[0;34m',
    'REVIEW_SCORED': '\033[0;34m',
    'COMPLETE': '\033[0;32m',
    'BLOCKED': '\033[0;31m',
}
color = state_colors.get(state, '\033[0m')
nc = '\033[0m'

print(f'  ${BOLD}Contract State:${NC} {color}{state}{nc}  (v{ver})')
print(f'  ${BOLD}Goal:${NC}           {goal[:70]}...' if len(goal) > 70 else f'  ${BOLD}Goal:${NC}           {goal}')
print(f'  ${BOLD}Score:${NC}          {score}/100 ({verdict})')
print(f'  ${BOLD}Phases:${NC}         {len(phases)} completed: {\" → \".join(phases[-4:])}')
print(f'  ${BOLD}ADRs:${NC}           {adrs} recorded')
if ext_skills:
    print(f'  ${BOLD}Extension Skills:${NC} {\", \".join(ext_skills)}')
" 2>/dev/null || echo "  ⚠️  Could not parse contract"
else
  echo -e "  ${YELLOW}⚠️  No contract found${NC}"
fi

# === Telemetry ===
echo ""
echo -e "${BOLD}⏱  Telemetry${NC}"
if [ -f "$TELEMETRY_DIR/summary.json" ] && [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json
with open('$TELEMETRY_DIR/summary.json') as f:
    t = json.load(f)
total_s = t.get('total_elapsed_s', 0)
phases = t.get('phases_completed', [])
print(f'  Total time:  {total_s}s across {len(phases)} phases')
" 2>/dev/null
else
  echo -e "  ${YELLOW}No telemetry data yet${NC}"
fi

# === Rules ===
echo ""
echo -e "${BOLD}📋 Rules${NC}"
if [ -f "$RULES_FILE" ] && [ -n "$PYTHON_CMD" ]; then
  $PYTHON_CMD -c "
import json
with open('$RULES_FILE') as f:
    r = json.load(f)
rules = r.get('rules', [])
critical = [x for x in rules if x.get('severity') == 'CRITICAL']
high = [x for x in rules if x.get('severity') == 'HIGH']
required_mcps = list(r.get('required_mcps', {}).keys())
required_mcps = [m for m in required_mcps if m != 'description']
mcps = list(r.get('required_mcps', {}).keys())
mcps = [m for m in mcps if m != 'description']
print(f'  {len(critical)} CRITICAL rules, {len(high)} HIGH rules')
if mcps:
    print(f'  Required MCPs: {\", \".join(mcps)}')
" 2>/dev/null
else
  echo -e "  ${YELLOW}No rules.json${NC}"
fi

# === Quick actions ===
echo ""
echo -e "${BOLD}⚡ Quick Actions${NC}"
echo "  bash .opencode/src/doctor.sh    — Run diagnostics"
echo "  bash .opencode/src/telemetry.sh  — View telemetry details"
echo "  bash .opencode/src/adr.sh        — Record new ADR"
echo ""
