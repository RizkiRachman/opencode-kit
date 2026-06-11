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
