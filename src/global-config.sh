#!/usr/bin/env bash
# opencode-kit global-config — resolve config from local → global → plugin default
# Usage: source src/global-config.sh && resolve_config "contract.json"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/platform.sh"

PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GLOBAL_CONFIG_DIR="$HOME/.config/opencode-kit"

# Resolve a config file from the lookup chain:
#   1. .opencode/<path>      (project override)
#   2. ~/.config/opencode-kit/<path>  (global defaults)
#   3. <plugin>/<path>       (plugin defaults)
# Returns: path to the first file found, or empty string if none found
resolve_config() {
  local rel_path="$1"

  # 1. Project override
  if [ -f ".opencode/$rel_path" ]; then
    echo ".opencode/$rel_path"
    return 0
  fi

  # 2. Global defaults
  if [ -f "$GLOBAL_CONFIG_DIR/$rel_path" ]; then
    echo "$GLOBAL_CONFIG_DIR/$rel_path"
    return 0
  fi

  # 3. Plugin defaults (templates/)
  if [ -f "$PLUGIN_ROOT/templates/$rel_path" ]; then
    echo "$PLUGIN_ROOT/templates/$rel_path"
    return 0
  fi

  # 4. Plugin defaults (root/)
  if [ -f "$PLUGIN_ROOT/$rel_path" ]; then
    echo "$PLUGIN_ROOT/$rel_path"
    return 0
  fi

  echo ""
  return 1
}

# Initialize global config from plugin defaults
# Copies templates/* and rules/* to ~/.config/opencode-kit/
init_global_config() {
  echo "[opencode-kit] Initializing global config at $GLOBAL_CONFIG_DIR"

  mkdir -p "$GLOBAL_CONFIG_DIR/orchestration" "$GLOBAL_CONFIG_DIR/rules"

  # Copy contract template
  if [ ! -f "$GLOBAL_CONFIG_DIR/orchestration/contract.json" ]; then
    cp "$PLUGIN_ROOT/templates/contract.json" "$GLOBAL_CONFIG_DIR/orchestration/contract.json"
    echo "  ✅ contract.json → global config"
  fi

  # Copy rules
  if [ ! -f "$GLOBAL_CONFIG_DIR/rules/rules.json" ]; then
    cp "$PLUGIN_ROOT/rules/rules.json" "$GLOBAL_CONFIG_DIR/rules/rules.json"
    echo "  ✅ rules.json → global config"
  fi

  echo "[opencode-kit] ✅ Global config initialized"
}

# Detect if the opencode-kit plugin is active
is_plugin_active() {
  # Check if .opencode/plugins/opencode-kit.js exists (sign of plugin mode)
  [ -f ".opencode/plugins/opencode-kit.js" ] && return 0
  # Check if ~/.config/opencode-kit exists (sign of global config)
  [ -d "$GLOBAL_CONFIG_DIR" ] && return 0
  return 1
}

# Export functions
export -f resolve_config init_global_config is_plugin_active
export GLOBAL_CONFIG_DIR
