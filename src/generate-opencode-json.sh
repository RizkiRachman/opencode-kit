#!/usr/bin/env bash
# generate-opencode-json.sh — Merge opencode-kit config into project opencode.json
# RULE: If key exists → append. If key doesn't exist → create.
# Usage: generate-opencode-json.sh [reference.json] [output.json]
# Defaults: reference=opencode-kit/opencode.json, output=./opencode.json.generated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(dirname "$SCRIPT_DIR")"
REFERENCE="${1:-$KIT_DIR/opencode.json.template}"
OUTPUT="${2:-./opencode.json.generated}"

if [ ! -f "$REFERENCE" ]; then
  echo "Error: Reference not found: $REFERENCE"
  exit 1
fi

python3 << PYEOF
import json
import os

REFERENCE = "$REFERENCE"
OUTPUT = "$OUTPUT"
KIT_DIR = "$KIT_DIR"

STRIP_KEYS = ["model", "fallback_models", "temperature", "top_p",
              "reasoningEffort", "textVerbosity", "steps"]

def strip_model_keys(cfg):
    """Remove model-related keys (user's global config provides these)."""
    return {k: v for k, v in cfg.items() if k not in STRIP_KEYS}

def merge_arrays(existing, incoming):
    """Append incoming items to existing, deduplicate."""
    combined = list(existing) + list(incoming)
    return list(dict.fromkeys(combined))  # preserve order, dedupe

def merge_objects(existing, incoming):
    """Deep merge: for each key in incoming, append if exists, create if not."""
    result = dict(existing)
    for key, val in incoming.items():
        if key in result:
            # Key exists — append based on type
            if isinstance(result[key], list) and isinstance(val, list):
                result[key] = merge_arrays(result[key], val)
            elif isinstance(result[key], dict) and isinstance(val, dict):
                result[key] = merge_objects(result[key], val)
            else:
                # Scalar: project wins (don't overwrite)
                pass
        else:
            # Key doesn't exist — create
            result[key] = val
    return result

# Load configs
with open(REFERENCE) as f:
    ref = json.load(f)

project = {}
if os.path.exists(OUTPUT):
    with open(OUTPUT) as f:
        project = json.load(f)

result = dict(project)  # start with project config

# === AGENTS ===
# For each agent in reference: append if exists, create if not
ref_agents = ref.get("agent", {})
if "agent" not in result:
    result["agent"] = {}

for name, ref_cfg in ref_agents.items():
    agent_cfg = strip_model_keys(ref_cfg)
    if name in result["agent"]:
        # Agent exists — merge skills (append), merge tools (append)
        existing = result["agent"][name]
        if "skills" in existing and "skills" in agent_cfg:
            existing["skills"] = merge_arrays(existing["skills"], agent_cfg["skills"])
        if "tools" in existing and "tools" in agent_cfg:
            existing["tools"] = merge_objects(existing["tools"], agent_cfg["tools"])
    else:
        # Agent doesn't exist — create
        result["agent"][name] = agent_cfg

# === PERMISSIONS ===
# For each permission: append if exists, create if not
ref_perms = ref.get("permission", {})
if "permission" not in result:
    result["permission"] = {}
for key, val in ref_perms.items():
    if key not in result["permission"]:
        result["permission"][key] = val
    # If exists, project wins (don't overwrite)

# === MCP ===
# For each MCP: append if exists, create if not
ref_mcps = ref.get("mcp", {})
if "mcp" not in result:
    result["mcp"] = {}
for key, val in ref_mcps.items():
    if key not in result["mcp"]:
        result["mcp"][key] = val

# === PLUGINS ===
# Merge lists (deduplicated)
ref_plugins = ref.get("plugin", [])
if "plugin" not in result:
    result["plugin"] = []
result["plugin"] = merge_arrays(result["plugin"], ref_plugins)

# === SKILLS PATHS ===
ref_skills = ref.get("skills", {})
if "skills" not in result:
    result["skills"] = {}
if "paths" not in result["skills"]:
    result["skills"]["paths"] = []
kit_skills_path = os.path.join(KIT_DIR, "skills")
if kit_skills_path not in result["skills"]["paths"]:
    result["skills"]["paths"].append(kit_skills_path)

# === NON-MERGED KEYS ===
# Copy reference keys that aren't merged above (project wins if exists)
SKIP_KEYS = {"agent", "permission", "mcp", "plugin", "skills"}
for key in ref:
    if key not in SKIP_KEYS and key not in result:
        result[key] = ref[key]

# Write output
with open(OUTPUT, "w") as f:
    json.dump(result, f, indent=2)

# Summary
proj_agents = len(project.get("agent", {}))
ref_agents_count = len(ref_agents)
total_agents = len(result.get("agent", {}))
print(f"Generated: {OUTPUT}")
print(f"  Agents: {total_agents} (project: {proj_agents}, kit: {ref_agents_count})")
print(f"  Permissions: {len(result.get('permission', {}))}")
print(f"  MCPs: {len(result.get('mcp', {}))}")
print(f"  Plugins: {len(result.get('plugin', []))}")
PYEOF