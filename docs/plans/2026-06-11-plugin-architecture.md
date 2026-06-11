# Plugin Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Convert opencode-kit from a per-project scaffold to a global OpenCode plugin with local-override config

**Architecture:** Pure JS plugin (superpowers pattern) using `@opencode-ai/plugin` SDK. Global config at `~/.config/opencode-kit/`, project override at `.opencode/`. Plugin registers skills + system prompt transform.

**Tech Stack:** Node.js, @opencode-ai/plugin SDK, shell scripts

---

### Task 1: Plugin Entry Point

**Files:**
- Create: `.opencode/plugins/opencode-kit.js` — main plugin JS
- Create: `.claude-plugin/plugin.json` — metadata
- Modify: `package.json` — add plugin entry, `@opencode-ai/plugin` dependency

- [ ] Create `.opencode/plugins/opencode-kit.js` — system prompt transform hook that injects contract loading + preflight
- [ ] Create `.claude-plugin/plugin.json` — name, description, version, author
- [ ] Update `package.json` — `"main": ".opencode/plugins/opencode-kit.js"`, add `@opencode-ai/plugin` dep

### Task 2: Global Config Resolution

**Files:**
- Create: `src/global-config.sh` — resolve config from local → global → plugin default

- [ ] Write resolution chain: `.opencode/` → `~/.config/opencode-kit/` → plugin `templates/`
- [ ] Add `init-global` command to copy plugin defaults to `~/.config/opencode-kit/`

### Task 3: Plugin Schema

**Files:**
- Create: `templates/opencode-kit.schema.json` — validate opencode.json agent config

- [ ] Schema defines default agents (orchestrator, planner, task-manager, etc.)
- [ ] Documents plugin ordering requirement (must be first in plugin array)

### Task 4: Init Coexistence

**Files:**
- Modify: `src/init.sh` — detect plugin, skip plugin-handled tasks

- [ ] If plugin detected (via `.opencode/plugins/opencode-kit.js`), skip skill/agent scaffolding
- [ ] Only scaffold per-project data: contract.json goal/scope, STATE.md, PROJECT.md

### Task 5: Documentation

**Files:**
- Modify: `README.md` — plugin installation, ordering requirement
- Modify: `CHANGELOG.md`

- [ ] Add "Install as plugin" section to README
- [ ] Document global vs local resolution
