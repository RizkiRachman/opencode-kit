# opencode-kit Bucket List

> **Status**: v0.5.2 published on npm as `@ikieaneh/opencode-kit`
> **Last updated**: 2026-06-11

## ✅ Done (v0.1 — v0.7)

### Core Framework
- [x] Contract system: `contract.json` with 8-state machine (INIT → PLAN → ... → COMPLETE + BLOCKED)
- [x] Rules engine: `rules.json` with 10 enforcement rules (CRITICAL/HIGH severity)
- [x] Pre-flight gate: branch check, contract load, state validation, MCP availability
- [x] Post-flight: contract persistence, telemetry recording, STATE.md sync
- [x] Scoring pipeline: Tier 1 (rule checks) + Tier 2 (LLM judge) + verdict thresholds
- [x] ADR generator: auto-ID, duplicate detection, structured decision log
- [x] Telemetry: phase transitions, elapsed time, summary report
- [x] Config resolution: `.opencode/` → `~/.config/opencode-kit/` → plugin defaults

### Plugin (v0.4+)
- [x] Plugin entry point: ESM with `config` + `messages.transform` hooks
- [x] Auto-init contract on first run (`ensureContract()`)
- [x] Unique contract keys per project (hashed from git remote)
- [x] 9 skills: orchestration-template, scoring-pipeline, adr-generator, qa-expert, system-analyst, token-optimize, verification-before-completion, learner, java-developer
- [x] Plugin metadata (`.claude-plugin/plugin.json`)
- [x] Plugin schema (`opencode-kit.schema.json`)
- [x] Proper logging (stderr-based, not console.log)

### Scripts & CLI
- [x] `init.sh` — scaffold framework (plugin-aware, `--force`, `--sample`)
- [x] `preflight.sh` — MCP checks, branch validation, state validation
- [x] `postflight.sh` — persist contract, telemetry, STATE.md sync
- [x] `verify.sh` — health check (files, permissions, agents)
- [x] `update.sh` — pull latest from GitHub, preserve contract state
- [x] `adr.sh` — ADR auto-generate (interactive + CLI)
- [x] `telemetry.sh` — view phase telemetry (summary/phases/json)
- [x] `platform.sh` — OS/arch/Python detection (macOS + Linux)
- [x] `global-config.sh` — config resolution chain
- [x] `cli.js` — `--version` / `--help`

### CI & Tests
- [x] GitHub Actions: ShellCheck + scaffold test + syntax check + integration + e2e
- [x] Integration tests: 7 tests (plugin load, hooks, hash, skills, JSON)
- [x] E2E tests: 9 tests (auto-init, bootstrap injection, hooks lifecycle)

### Documentation
- [x] README (Best-README-Template), CHANGELOG, CONTRIBUTING
- [x] Quickstart guide (`docs/examples/QUICKSTART.md`)
- [x] Model config examples (`docs/examples/model-configs.md`)

### npm
- [x] Published as `@ikieaneh/opencode-kit@0.5.2`
- [x] Agent templates: generic (no Java/mvn hardcoded)
- [x] `init --sample`: uses `your-model` placeholders

---

## 🟡 Next Up (Priority Order)

### P1 — Implemented
- [x] **Generic skill names in templates**: Replaced specific skill names (`qa-expert`, `brainstorming`, etc.) with generic role descriptions. Schema uses generic descriptions.
- [x] **MCP abstraction**: Preflight MCP checks now read from `rules.json.required_mcps`. Add/remove MCPS by editing rules.json, not shell scripts.
- [x] **Persistence fallback**: If `lean-ctx` unavailable, contract persists to `.opencode/state/contract.json` instead.
- [x] **`experimental.chat.messages.transform` API**: Documented in README Known Limitations section.

### P2 — Implemented
- [x] **Rule severity config**: `validation.rule_overrides` in contract.json — projects can override rule severity (e.g., make PERSIST_001 from FLAG to BLOCK)
- [x] **`opencode-kit doctor`**: `src/doctor.sh` — diagnostic command checking MCPs, contract, rules, git branch, persistence, plugin config
- [x] **Plugin init order conflict detection**: Plugin.js warns if opencode-kit isn't first in the plugin array

### P3 — Implemented
- [x] **Dashboard CLI**: `opencode-kit status` — pretty terminal dashboard (contract state, telemetry, rules, quick actions)
- [x] **Template generator**: `opencode-kit new skill` — scaffolds a new skill with `mkdir -p .opencode/skills/<name>/SKILL.md`
- [x] **Analytics**: `opencode-kit analytics` — aggregate telemetry with phase breakdown, time estimates, token cost estimate
- [ ] **Web UI**: Browser dashboard for contract overview (deferred — low priority)
- [ ] **Plugin marketplace entry**: Already on npm with proper keywords
- [ ] **AI assistant for contract**: Auto-suggest next state transitions (deferred — needs ML)

---

## 🧠 Ideas (Not Yet Scoped)

- `opencode-kit analytics` — aggregate telemetry across projects
- `opencode-kit diff` — compare contract state between branches
- VSCode extension — show contract state in editor status bar
- GitHub App — auto-create ADRs from PR descriptions
- Slack/Telegram bot — notify on BLOCKED state
