# Changelog

All notable changes to opencode-kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-06-11

### Added

- **Plugin entry point**: `.opencode/plugins/opencode-kit.js` — ESM plugin that injects contract loading + pre-flight enforcement into every session. Uses `config` hook to register skills directory and `experimental.chat.messages.transform` hook to inject bootstrap context.
- **Plugin metadata**: `.claude-plugin/plugin.json` — name, version, description, author, keywords.
- **Skills**: 3 auto-registered skills in `skills/`:
  - `orchestration-template` — contract protocol, state machine, persist rules
  - `scoring-pipeline` — Tier 1 + Tier 2 + verdict thresholds
  - `adr-generator` — ADR format, auto-ID, when-to-record rules
- **Global config resolution**: `src/global-config.sh` — lookup chain: `.opencode/` → `~/.config/opencode-kit/` → plugin defaults. `init_global_config()` copies plugin defaults to user home. `is_plugin_active()` detects plugin mode.
- **Plugin schema**: `templates/opencode-kit.schema.json` — validates opencode.json agent config for plugin users. Documents plugin ordering requirement (must be first in plugin array).
- **Plugin-aware init**: `init.sh` detects plugin mode, skips shell script scaffolding (plugin handles via system prompt), only scaffolds per-project data (contract.json, verify.sh, platform.sh).

### Changed

- `package.json` — updated to v0.4.0, added `"type": "module"`, `"main": ".opencode/plugins/opencode-kit.js"`, plugin exports, new keywords + repo URLs
- `README.md` — plugin installation docs, ordering requirement

## [0.3.0] - 2026-06-11

### Added

- **Cross-platform support**: `src/platform.sh` — detects OS (macOS/Linux), architecture (arm64/amd64), and Python command (python3/python). All scripts source it via `. "$SCRIPT_DIR/platform.sh"` and use `$PYTHON_CMD` instead of hardcoded `python3`.
- **CI pipeline**: `.github/workflows/validate.yml` — 3 jobs: ShellCheck linting, scaffold test (init + verify + preflight on Ubuntu), bash syntax check.
- **Update command**: `src/update.sh` — clones latest opencode-kit from GitHub, updates scripts and templates while preserving existing contract.json state (goal, scope, decisions, metrics). Supports `--dry-run` and `--version <tag>`.
- **Scoring Tier 2**: `templates/judge-prompt.md` — canonical LLM judge prompt for orchestrator agent. Structured 4-dimension evaluation (requirements 0-40, governance 0-30, completeness 0-20, edge cases 0-10). SCORE_002 rule enforces canonical source.
- **Telemetry system**: `src/telemetry.sh` — records phase transitions with timestamps, elapsed time, and state changes. `postflight.sh` auto-records to `.opencode/telemetry/phases.jsonl`. `telemetry.sh --summary` for quick view, `--phases` for detailed, `--json` for raw. Phase start captured by `preflight.sh`.
- **ADR generator copied**: `init.sh` now copies `adr.sh` and `platform.sh` to `.opencode/src/`.
- **updated version**: contract_version field, v0.2.0 → v0.3.0 in init.sh, rules.json

### Changed

- All scripts: source `platform.sh`, use `$PYTHON_CMD` for cross-platform Python detection
- `postflight.sh`: telemetry recording (phases.jsonl, summary.json, phase start/end timing)
- `preflight.sh`: records phase start timestamp for telemetry
- `verify.sh`: checks telemetry directory, expanded script check list
- `rules.json`: expanded Scoring Tier 2 judge prompt, added SCORE_002 rule

## [0.2.0] - 2026-06-11

### Added

- **MCP auto-detection**: `preflight.sh` now checks availability of lean-ctx, gitnexus, graphify, and context7. Reports status with color-coded warnings. Non-blocking for missing MCPs but warns about capability gaps.
- **Contract state validation**: `preflight.sh` parses contract.json at startup, validates state field against known states. Detects malformed JSON.
- **Rules validation**: `rules/validation.sh` — validates agent actions against 5 rule categories: branch (PREFLIGHT_002), state (STATE_001), schema (SCHEMA_001), impact analysis (IMPACT_001), persistence (PERSIST_001). Supports `--strict` mode treating HIGH as BLOCK.
- **Re-init with backup**: `init.sh --force` now backs up existing `.opencode/` to `.opencode.bak.<timestamp>` before clean scaffold. Non-force mode adds missing files without overwriting.
- **ADR auto-generate**: `src/adr.sh` — interactive or CLI mode (`--title`, `--context`, `--decision`, `--alternatives`, `--consequences`). Auto-assigns IDs (ADR-001, ADR-002...). Detects duplicate titles. Injects into contract.json `decisions.adr_log[]`.

### Changed

- `preflight.sh` — added Check 5 (contract state validation), expanded Check 3 to full MCP suite
- `init.sh` — version bump to v0.2.0, proper force-overwrite with backup

## [0.1.0] - 2026-06-11

### Added

- **Contract system**: `templates/contract.json` — shared state machine with 8-state transitions (INIT → PLAN → PLAN_SCORED → EXECUTE → EXECUTE_SCORED → REVIEW → REVIEW_SCORED → COMPLETE, plus BLOCKED). Renamed from "envelope" to "contract" for enforceability.
- **Rules engine**: `rules/rules.json` — 9 machine-readable rules with CRITICAL/HIGH severity. Includes state machine transitions, scoring thresholds, and rule definitions.
- **Pre-flight enforcement**: `src/preflight.sh` — validates contract exists, branch is not main, lean-ctx reachable, rules.json present. Must run before any tool call.
- **Post-flight persistence**: `src/postflight.sh` — auto-persists contract to lean-ctx, updates STATE.md, saves session.
- **Scaffolding**: `src/init.sh` — `npx opencode-kit init` one-command setup. Dependency checks, file scaffolding, verification.
- **Health check**: `src/verify.sh` — validates all files present, pre-flight gates exist in agent .md files, scripts are executable.
- **Agent templates**: 6 agent .md files (orchestrator, planner, task-manager, code-reviewer, learner, fixer) each with embedded pre-flight gate as the FIRST instruction.
- **ADR format**: Architecture Decision Records as `decisions.adr_log[]` in contract.json — structured log with title, context, decision, alternatives, consequences.
- **Scoring pipeline**: Tier 1 (rule checks) + Tier 2 (LLM judge) + Tier 3 (combined verdict). Thresholds: ≥70 PASS, 50-69 RETRY, <50 BLOCKED.
- **macOS M-series support**: All scripts use portable POSIX shell, compatible with Apple Silicon.

[0.1.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.1.0
