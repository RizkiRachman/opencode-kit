# Changelog

All notable changes to opencode-kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
