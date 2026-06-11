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

### P1 — Must Have
- [ ] **Generic skill names in templates**: Replace specific skill names (`qa-expert`, `brainstorming`, etc.) with generic descriptions. Users override via `opencode.json` skills array.
- [ ] **MCP abstraction**: Make preflight MCP checks pluggable — define required MCPs in `rules.json` or contract, not hardcoded in `preflight.sh`
- [ ] **Persistence fallback**: If `lean-ctx` unavailable, persist contract to file only (`.opencode/state/contract.json`)
- [ ] **`experimental.chat.messages.transform` API**: Monitor OpenCode plugin SDK for breaking changes to this experimental hook

### P2 — Should Have
- [ ] **Cross-project contract sharing**: Share contract state across monorepo services
- [ ] **Plugin init order conflict detection**: Warn if multiple plugins modify same system prompt areas
- [ ] **Rule severity config**: Allow projects to override rule severity (e.g., make `PERSIST_001` from FLAG to BLOCK)
- [ ] **Contract migration**: Schema versioning — auto-migrate old contract.json to new schema
- [ ] **`opencode-kit doctor`**: Diagnostic command that checks all MCPs, permissions, and config

### P3 — Nice to Have
- [ ] **Web UI**: Browser dashboard for contract overview (state, phases, ADRs, telemetry)
- [ ] **Plugin marketplace entry**: Register opencode-kit in OpenCode's plugin discovery
- [ ] **Unscoped npm package**: Publish as `opencode-kit` (requires paid npm account)
- [ ] **Multi-repo orchestration**: Coordinate contract across multiple git repos
- [ ] **Template generator**: `opencode-kit new skill` — scaffold a new skill SKILL.md
- [ ] **Dashboard CLI**: `opencode-kit status` — pretty terminal dashboard of contract state
- [ ] **AI assistant for contract**: Auto-suggest next state transitions based on project history

---

## 🧠 Ideas (Not Yet Scoped)

- `opencode-kit analytics` — aggregate telemetry across projects
- `opencode-kit diff` — compare contract state between branches
- VSCode extension — show contract state in editor status bar
- GitHub App — auto-create ADRs from PR descriptions
- Slack/Telegram bot — notify on BLOCKED state
