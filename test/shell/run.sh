#!/usr/bin/env bash
# opencode-kit shell test runner
# Usage: bash test/shell/run.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[opencode-kit] Running shell script tests..."
echo "==========================================="

bash "$SCRIPT_DIR/test_basics.sh"
