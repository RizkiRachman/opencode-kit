#!/usr/bin/env bash
# merge-config.sh — Inheritance merge utility for opencode-kit
# Merges base config with project overrides using _meta extends

set -euo pipefail

# Usage: merge-config.sh <base.json> <project.json> [output.json]
# If output.json is omitted, prints to stdout

BASE_FILE="${1:-}"
PROJECT_FILE="${2:-}"
OUTPUT_FILE="${3:-}"

if [[ -z "$BASE_FILE" || -z "$PROJECT_FILE" ]]; then
  echo "Usage: merge-config.sh <base.json> <project.json> [output.json]"
  exit 1
fi

if [[ ! -f "$BASE_FILE" ]]; then
  echo "Error: Base file not found: $BASE_FILE"
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Error: Project file not found: $PROJECT_FILE"
  exit 1
fi

# Merge using Python
python3 << 'PYEOF'
import json
import sys
import os

def is_array(v):
    return isinstance(v, list)

def is_object(v):
    return isinstance(v, dict) and not isinstance(v, list)

def dedupe(arr):
    """Deduplicate array, preserving order."""
    seen = set()
    result = []
    for item in arr:
        key = json.dumps(item, sort_keys=True) if isinstance(item, (dict, list)) else str(item)
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result

def merge(base, project, overrides=None, appends=None, excludes=None):
    """
    Deep merge base with project config.
    
    - Scalars: project wins
    - Arrays: concatenated (deduped)
    - Objects: deep merged
    - _meta overrides: specific fields override instead of merge
    - _meta appends: specific fields only append
    - _meta excludes: excluded from inheritance
    """
    if overrides is None:
        overrides = set()
    if appends is None:
        appends = set()
    if excludes is None:
        excludes = set()
    
    result = {}
    
    # Start with base
    if is_object(base):
        for k, v in base.items():
            if k in excludes:
                continue
            result[k] = v
    
    # Merge project
    if is_object(project):
        for k, v in project.items():
            if k == '_meta':
                continue  # Handle _meta separately
            if k in excludes:
                continue
            
            if k in overrides:
                # Override mode: project wins completely
                result[k] = v
            elif k in appends:
                # Append mode: always array concat
                if is_array(result.get(k)):
                    result[k] = dedupe(result[k] + v)
                else:
                    result[k] = v
            elif k in result and is_array(result[k]) and is_array(v):
                # Array merge: concat + dedupe
                result[k] = dedupe(result[k] + v)
            elif k in result and is_object(result[k]) and is_object(v):
                # Object merge: recursive
                result[k] = merge(result[k], v, overrides, appends, excludes)
            else:
                # Scalar or new field: project wins
                result[k] = v
    
    return result

def load_with_meta(filepath):
    """Load JSON and extract _meta if present."""
    with open(filepath) as f:
        data = json.load(f)
    
    meta = data.pop('_meta', {})
    return data, meta

# Load files
base_data = json.load(open(sys.argv[1]))
project_data, project_meta = load_with_meta(sys.argv[2])

# Extract merge directives from _meta
overrides = set(project_meta.get('overrides', []))
appends = set(project_meta.get('appends', []))
excludes = set(project_meta.get('excludes', []))

# Perform merge
merged = merge(base_data, project_data, overrides, appends, excludes)

# Add _meta to result
merged['_meta'] = {
    'extends': project_meta.get('extends', 'unknown'),
    'merged_at': __import__('datetime').datetime.utcnow().isoformat() + 'Z'
}

# Output
output = sys.argv[3] if len(sys.argv) > 3 else None
if output:
    with open(output, 'w') as f:
        json.dump(merged, f, indent=2)
    print(f"Merged config written to: {output}")
else:
    print(json.dumps(merged, indent=2))
PYEOF