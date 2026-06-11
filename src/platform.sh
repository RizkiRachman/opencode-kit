#!/usr/bin/env bash
# opencode-kit platform — cross-platform detection and helpers
# Source this from any script: . "$(dirname "$0")/platform.sh"
set -euo pipefail

# --- OS Detection ---
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux"  ;;
  *)      OS="other"  ;;
esac

# --- Architecture ---
ARCH="unknown"
case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="amd64" ;;
  *)             ARCH="other" ;;
esac

# --- Python command (python3 on macOS, python on some Linux) ---
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
  PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
  PYTHON_CMD="python"
fi

# --- Bash compatibility ---
BASH_VERSION=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0")

# --- Export ---
export OS ARCH PYTHON_CMD BASH_VERSION

# --- JSON parsing with fallback: python3 → jq → error ---
json_get() {
  # Usage: json_get <file> <key>
  # Returns the value of <key> from <file> as JSON
  local file="$1"
  local key="$2"
  if [ -n "$PYTHON_CMD" ]; then
    $PYTHON_CMD -c "import json,sys; d=json.load(open('$file')); print(json.dumps(d.get('$key','')))" 2>/dev/null
  elif command -v jq &>/dev/null; then
    jq -r ".$key" "$file" 2>/dev/null
  else
    echo ""
    return 1
  fi
}

json_has_field() {
  # Usage: json_has_field <file> <key>
  # Returns 0 if key exists, 1 if not or error
  local file="$1"
  local key="$2"
  if [ -n "$PYTHON_CMD" ]; then
    $PYTHON_CMD -c "import json,sys; d=json.load(open('$file')); sys.exit(0 if '$key' in d else 1)" 2>/dev/null
  elif command -v jq &>/dev/null; then
    jq -e ".$key" "$file" >/dev/null 2>&1
  else
    return 1
  fi
}
