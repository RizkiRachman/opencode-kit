#!/usr/bin/env bash
# opencode-kit new skill — scaffold a new skill SKILL.md
# Usage: bash src/new-skill.sh <skill-name> [description]
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

NAME="${1:-}"
DESC="${2:-A custom skill for this project}"
SKILLS_DIR=".opencode/skills"

if [ -z "$NAME" ]; then
  echo -e "${RED}Usage: bash src/new-skill.sh <skill-name> [description]${NC}"
  echo "  Example: bash src/new-skill.sh python-conventions \"Python/Django conventions\""
  exit 1
fi

SKILL_PATH="$SKILLS_DIR/$NAME"
SKILL_FILE="$SKILL_PATH/SKILL.md"

if [ -d "$SKILL_PATH" ]; then
  echo -e "${RED}❌ Skill already exists: $SKILL_PATH${NC}"
  exit 1
fi

mkdir -p "$SKILL_PATH"

cat > "$SKILL_FILE" << SKILLEOF
---
description: $DESC
---

# $NAME

## Conventions

...

## Commands

| Action | Command |
|--------|---------|
| Test | ... |
| Build | ... |
| Format | ... |

## Rules

...
SKILLEOF

echo -e "${GREEN}✅ Skill created: $SKILL_FILE${NC}"
echo ""
echo "  To use it, add to opencode.json:"
echo '  "skills": ["'$NAME'", "orchestration-template"]'
echo ""
echo "  Or load it ad-hoc with: /skill $NAME"
