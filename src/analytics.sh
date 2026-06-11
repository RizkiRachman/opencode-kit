#!/usr/bin/env bash
# opencode-kit analytics — aggregate telemetry across phases
# Usage: bash src/analytics.sh [--json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./platform.sh
. "$SCRIPT_DIR/platform.sh"

TELEMETRY_DIR=".opencode/telemetry"
CONTRACT_FILE=".opencode/orchestration/contract.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-table}"

echo -e "${CYAN}📊 opencode-kit Analytics${NC}"
echo ""

if [ ! -f "$TELEMETRY_DIR/phases.jsonl" ] || [ ! -f "$TELEMETRY_DIR/summary.json" ]; then
  echo -e "${YELLOW}No telemetry data yet. Run a few phases first.${NC}"
  exit 0
fi

if [ -z "$PYTHON_CMD" ]; then
  echo -e "${RED}Python required for analytics.${NC}"
  exit 1
fi

$PYTHON_CMD -c "
import json

# Load phases
phases = []
try:
    with open('$TELEMETRY_DIR/phases.jsonl') as f:
        for line in f:
            line = line.strip()
            if line:
                phases.append(json.loads(line))
except:
    pass

# Load summary
summary = {}
try:
    with open('$TELEMETRY_DIR/summary.json') as f:
        summary = json.load(f)
except:
    pass

if not phases:
    print('  No phases recorded')
    exit(0)

total_ms = sum(p.get('elapsed_ms', 0) for p in phases)
avg_ms = total_ms / len(phases) if phases else 0

print(f'  Total sessions:  {len(phases)}')
print(f'  Total time:      {total_ms/1000:.1f}s ({total_ms/60000:.1f}m)')
print(f'  Avg per phase:   {avg_ms/1000:.1f}s')
print('')
print(f'  Phase Breakdown:')
for p in phases:
    frm = p.get('from', '?')
    to = p.get('to', '?')
    ms = p.get('elapsed_ms', 0)
    bar = '#' * max(1, int(ms / max(1, total_ms) * 30))
    print(f'    {frm:16s} → {to:16s}  {ms/1000:6.1f}s  {bar}')

# Cost estimate (rough: ~$0.15/1M tokens, ~1000 tok/s)
est_tokens = int(total_ms / 1000 * 1000)  # rough: 1000 tok/sec
est_cost = est_tokens / 1_000_000 * 0.15
print(f'')
print(f'  Estimated tokens: {est_tokens:,} (~{est_cost:.4f} USD at $0.15/1M tok)')
" 2>/dev/null || echo "  ⚠️  Analytics failed"
