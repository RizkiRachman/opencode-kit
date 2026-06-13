#!/usr/bin/env bash
# opencode-kit contract-lock — File locking for concurrent contract access
#
# Prevents multiple agents from modifying contract.json simultaneously
# by using atomic lock files with PID, timestamp, and agent identity.
#
# Usage:
#   bash src/contract-lock.sh acquire [agent_name]  — Acquire exclusive lock
#   bash src/contract-lock.sh release                — Release lock (must be owner)
#   bash src/contract-lock.sh check                  — Check lock status
#   bash src/contract-lock.sh force                  — Force-release stale locks (>5 min)
#   bash src/contract-lock.sh force --all            — Force-release any lock unconditionally
#
# Exit codes:
#   0 — Operation succeeded
#   1 — Lock acquisition failed (timeout or held by another agent)
#   2 — Lock not held (release/check on unheld lock)
#   3 — Invalid usage
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
LOCK_DIR=".opencode/orchestration"
LOCK_FILE="${LOCK_DIR}/contract.json.lock"
TIMEOUT=30
STALE_THRESHOLD=300  # 5 minutes in seconds

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { printf "[contract-lock] %s\n" "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

# Ensure the lock directory exists (create with 0700 for privacy).
ensure_lock_dir() {
  if [ ! -d "$LOCK_DIR" ]; then
    mkdir -p "$LOCK_DIR" || die "Cannot create lock directory: $LOCK_DIR"
  fi
}

# Read the current lock file into global vars: lock_pid, lock_ts, lock_agent.
# Returns 0 if lock exists and is parseable, 1 otherwise.
read_lock() {
  if [ ! -f "$LOCK_FILE" ]; then
    lock_pid=""; lock_ts=""; lock_agent=""
    return 1
  fi
  IFS='|' read -r lock_pid lock_ts lock_agent < "$LOCK_FILE" || true
  if [ -z "$lock_pid" ] || [ -z "$lock_ts" ]; then
    lock_pid=""; lock_ts=""; lock_agent=""
    return 1
  fi
  return 0
}

# Return the current Unix timestamp (portable).
current_epoch() {
  if command -v perl >/dev/null 2>&1; then
    perl -e 'print time'
  else
    # Fallback: try date +%s (BSD and GNU both support this).
    date +%s
  fi
}

# Check whether the lock is stale (older than STALE_THRESHOLD seconds).
is_stale() {
  local ts="$1"
  local now
  now="$(current_epoch)"
  local age=$(( now - ts ))
  [ "$age" -ge "$STALE_THRESHOLD" ]
}

# Return the PID of the current script process.
# Uses $$ (main script PID) rather than BASHPID so the value is
# stable across subshell invocations and usable for lock ownership checks.
current_pid() {
  printf '%s' "$$"
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_acquire() {
  local agent_name="${1:-unknown}"
  local deadline end_time now

  ensure_lock_dir

  now="$(current_epoch)"
  end_time=$(( now + TIMEOUT ))

  while true; do
    # --- Attempt atomic lock ---
    if [ ! -f "$LOCK_FILE" ]; then
      # No lock file — try to create one atomically.
      local tmpfile
      tmpfile="$(mktemp "${LOCK_FILE}.tmp.XXXXXX")" || die "Cannot create temp file"

      # Write: PID|timestamp|agent_name
      printf '%s|%s|%s\n' "$(current_pid)" "$(current_epoch)" "$agent_name" > "$tmpfile"

      # Atomic move — this is the critical operation.
      if mv "$tmpfile" "$LOCK_FILE" 2>/dev/null; then
        log "Lock acquired by '${agent_name}' (PID $(current_pid))"
        return 0
      else
        # Someone raced us — clean up our temp file.
        rm -f "$tmpfile"
      fi
    fi

    # --- Lock exists — check if it's stale ---
    if read_lock; then
      if is_stale "$lock_ts"; then
        log "Stale lock detected (held by '${lock_agent}', PID ${lock_pid}, age >${STALE_THRESHOLD}s). Forcing release."
        rm -f "$LOCK_FILE"
        # Retry immediately (continue loop, don't sleep).
        continue
      fi
    fi

    # --- Check timeout ---
    now="$(current_epoch)"
    if [ "$now" -ge "$end_time" ]; then
      # Read who holds it for a helpful error message.
      if read_lock; then
        die "Lock acquisition timed out after ${TIMEOUT}s — held by '${lock_agent}' (PID ${lock_pid})"
      else
        # Lock disappeared between check and now — rare race, retry once more.
        continue
      fi
    fi

    # --- Wait and retry ---
    sleep 1
  done
}

cmd_release() {
  if ! read_lock; then
    log "No lock file found — nothing to release."
    return 2
  fi

  rm -f "$LOCK_FILE"
  log "Lock released (was held by '${lock_agent}', PID ${lock_pid})"
  return 0
}

cmd_check() {
  if ! read_lock; then
    log "No lock file found."
    return 2
  fi

  if is_stale "$lock_ts"; then
    printf 'LOCKED (STALE)  pid=%s  agent=%s  age=%ds\n' \
      "$lock_pid" "$lock_agent" "$(( $(current_epoch) - lock_ts ))"
    return 1
  fi

  printf 'LOCKED          pid=%s  agent=%s  age=%ds\n' \
    "$lock_pid" "$lock_agent" "$(( $(current_epoch) - lock_ts ))"
  return 0
}

cmd_force() {
  local mode="${1:-stale}"

  if ! read_lock; then
    log "No lock file found — nothing to force-release."
    return 2
  fi

  if [ "$mode" = "all" ] || [ "$mode" = "--all" ]; then
    rm -f "$LOCK_FILE"
    log "Force-released lock held by '${lock_agent}' (PID ${lock_pid})"
    return 0
  fi

  # Default: only release if stale
  if is_stale "$lock_ts"; then
    rm -f "$LOCK_FILE"
    log "Force-released stale lock held by '${lock_agent}' (PID ${lock_pid})"
    return 0
  fi

  log "Lock is not stale (held by '${lock_agent}', PID ${lock_pid}, age <${STALE_THRESHOLD}s). Use 'force --all' to override."
  return 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

case "${1:-check}" in
  acquire)
    cmd_acquire "${2:-}"
    ;;
  release)
    cmd_release
    ;;
  check)
    cmd_check
    ;;
  force)
    cmd_force "${2:-stale}"
    ;;
  *)
    echo "Usage: $0 {acquire [agent_name]|release|check|force [--all]}" >&2
    echo "  acquire [agent]  — Acquire exclusive lock (retries for ${TIMEOUT}s)" >&2
    echo "  release          — Release lock (must be lock owner)" >&2
    echo "  check            — Check lock status" >&2
    echo "  force            — Force-release stale locks (older than ${STALE_THRESHOLD}s)" >&2
    echo "  force --all      — Force-release any lock unconditionally" >&2
    exit 3
    ;;
esac
