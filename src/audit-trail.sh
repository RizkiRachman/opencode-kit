#!/usr/bin/env bash
# opencode-kit audit-trail — Structured compliance logging
#
# Creates append-only JSONL audit logs for workflow compliance tracking.
# Every entry is timestamped, attributed, and traces contract state + branch.
#
# Usage:
#   bash src/audit-trail.sh log <event_type> <agent> <action> [details_json]
#   bash src/audit-trail.sh transition <from_state> <to_state> <agent>
#   bash src/audit-trail.sh scoring <agent> <score> <verdict>
#   bash src/audit-trail.sh violation <agent> <rule_id> <message>
#   bash src/audit-trail.sh query [--type TYPE] [--agent AGENT] [--since DATE]
#   bash src/audit-trail.sh export [--format json|csv]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AUDIT_DIR=".opencode/audit"
AUDIT_LOG="$AUDIT_DIR/audit.log"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

_mkdir() {
  mkdir -p "$AUDIT_DIR"
}

_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

_contract_state() {
  local contract=".opencode/orchestration/contract.json"
  if [ -f "$contract" ]; then
    python3 -c "
import json, sys
try:
    with open('$contract') as f:
        d = json.load(f)
    print(d.get('state', d.get('phase', 'UNKNOWN')))
except Exception:
    print('UNKNOWN')
" 2>/dev/null || echo "UNKNOWN"
  else
    echo "UNINIT"
  fi
}

# ---------------------------------------------------------------------------
# core: write one JSONL entry
# ---------------------------------------------------------------------------

_write_entry() {
  local event_type="$1"
  local agent="$2"
  local action="$3"
  local details
  if [ $# -ge 4 ]; then
    details="$4"
  else
    details="{}"
  fi

  _mkdir

  local ts
  ts="$(_iso8601)"
  local branch
  branch="$(_branch)"
  local cstate
  cstate="$(_contract_state)"

  printf '{"timestamp":"%s","event_type":"%s","agent":"%s","action":"%s","details":%s,"contract_state":"%s","branch":"%s"}\n' \
    "$ts" "$event_type" "$agent" "$action" "$details" "$cstate" "$branch" >> "$AUDIT_LOG"
}

# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------

cmd_log() {
  if [ $# -lt 3 ]; then
    echo "Usage: bash src/audit-trail.sh log <event_type> <agent> <action> [details_json]" >&2
    exit 1
  fi
  local event_type="$1"
  local agent="$2"
  local action="$3"
  local details
  if [ $# -ge 4 ]; then
    details="$4"
  else
    details="{}"
  fi
  _write_entry "$event_type" "$agent" "$action" "$details"
  echo "logged: $event_type/$agent/$action" >&2
}

cmd_transition() {
  if [ $# -lt 3 ]; then
    echo "Usage: bash src/audit-trail.sh transition <from_state> <to_state> <agent>" >&2
    exit 1
  fi
  local from="$1"
  local to="$2"
  local agent="$3"
  local details
  details=$(printf '{"from":"%s","to":"%s"}' "$from" "$to")
  _write_entry "transition" "$agent" "state_change" "$details"
  echo "logged: transition $from → $to ($agent)" >&2
}

cmd_scoring() {
  if [ $# -lt 3 ]; then
    echo "Usage: bash src/audit-trail.sh scoring <agent> <score> <verdict>" >&2
    exit 1
  fi
  local agent="$1"
  local score="$2"
  local verdict="$3"
  local details
  details=$(printf '{"score":"%s","verdict":"%s"}' "$score" "$verdict")
  _write_entry "scoring" "$agent" "score_computed" "$details"
  echo "logged: scoring $agent = $score ($verdict)" >&2
}

cmd_violation() {
  if [ $# -lt 3 ]; then
    echo "Usage: bash src/audit-trail.sh violation <agent> <rule_id> <message>" >&2
    exit 1
  fi
  local agent="$1"
  local rule_id="$2"
  local message="$3"
  local details
  details=$(printf '{"rule_id":"%s","message":"%s"}' "$rule_id" "$message")
  _write_entry "violation" "$agent" "rule_violated" "$details"
  echo "logged: violation $agent / $rule_id" >&2
}

cmd_query() {
  if [ ! -f "$AUDIT_LOG" ]; then
    echo "[]"
    return
  fi

  local filter_type=""
  local filter_agent=""
  local filter_since=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --type)  shift; filter_type="$1"  ;;
      --agent) shift; filter_agent="$1" ;;
      --since) shift; filter_since="$1" ;;
      *) echo "Unknown query option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  # Build a Python filter pipeline for correctness (JSONL parsing)
  python3 -c "
import json, sys

filter_type = '$filter_type'
filter_agent = '$filter_agent'
filter_since = '$filter_since'

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
    except json.JSONDecodeError:
        continue
    if filter_type and entry.get('event_type') != filter_type:
        continue
    if filter_agent and entry.get('agent') != filter_agent:
        continue
    if filter_since and entry.get('timestamp', '') < filter_since:
        continue
    print(json.dumps(entry))
" < "$AUDIT_LOG"
}

cmd_export() {
  local format="json"

  while [ $# -gt 0 ]; do
    case "$1" in
      --format) shift; format="$1" ;;
      *) echo "Unknown export option: $1" >&2; exit 1 ;;
    esac
    shift
  done

  if [ ! -f "$AUDIT_LOG" ]; then
    case "$format" in
      json) echo "[]" ;;
      csv)  echo "timestamp,event_type,agent,action,contract_state,branch" ;;
    esac
    return
  fi

  case "$format" in
    json)
      python3 -c "
import json, sys
entries = [json.loads(l) for l in sys.stdin if l.strip()]
print(json.dumps(entries, indent=2))
" < "$AUDIT_LOG"
      ;;
    csv)
      echo "timestamp,event_type,agent,action,contract_state,branch"
      python3 -c "
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        e = json.loads(line)
    except json.JSONDecodeError:
        continue
    ts = e.get('timestamp', '')
    et = e.get('event_type', '')
    ag = e.get('agent', '')
    ac = e.get('action', '')
    cs = e.get('contract_state', '')
    br = e.get('branch', '')
    print(f'{ts},{et},{ag},{ac},{cs},{br}')
" < "$AUDIT_LOG"
      ;;
    *)
      echo "Unsupported format: $format (use json or csv)" >&2
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  log)
    cmd_log "$@"
    ;;
  transition)
    cmd_transition "$@"
    ;;
  scoring)
    cmd_scoring "$@"
    ;;
  violation)
    cmd_violation "$@"
    ;;
  query)
    cmd_query "$@"
    ;;
  export)
    cmd_export "$@"
    ;;
  help|--help|-h)
    echo "opencode-kit audit-trail — Structured compliance logging"
    echo ""
    echo "Usage:"
    echo "  bash src/audit-trail.sh log <event_type> <agent> <action> [details_json]"
    echo "  bash src/audit-trail.sh transition <from_state> <to_state> <agent>"
    echo "  bash src/audit-trail.sh scoring <agent> <score> <verdict>"
    echo "  bash src/audit-trail.sh violation <agent> <rule_id> <message>"
    echo "  bash src/audit-trail.sh query [--type TYPE] [--agent AGENT] [--since DATE]"
    echo "  bash src/audit-trail.sh export [--format json|csv]"
    echo ""
    echo "Audit log: .opencode/audit/audit.log (append-only JSONL)"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Run 'bash src/audit-trail.sh help' for usage." >&2
    exit 1
    ;;
esac
