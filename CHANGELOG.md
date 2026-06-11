# Changelog

All notable changes to opencode-kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
