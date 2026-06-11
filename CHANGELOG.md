# Changelog

All notable changes to opencode-kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — Iteration 6

### Fixed

- **code-reviewer.md**: Duplicate `"npm test": allow` key in YAML frontmatter — same pattern as orchestrator.md but missed in prior iteration. Removed duplicate. (#22)
- **task-manager.md**: Duplicate `"npm test": allow` key in YAML frontmatter — same pattern. Removed duplicate. (#22)
- **learner.md**: Stale reference to "11 memory systems" — table only lists 7 entries. Changed to "all memory systems listed below". (#22)

## [0.6.9] - 2026-06-11

### Fixed

- **orchestrator.md**: Duplicate `"npm test": allow` key in YAML frontmatter — second instance silently overrode the first. Removed duplicate. (#21)
- **init.sh**: `postflight.py` was copied without `chmod +x`, causing `verify.sh` to emit a warning about non-executable script. Added `chmod +x`. (#21)

## [0.6.8] - 2026-06-11

### Fixed

- **release.yml**: `templates/contract.json` `contract_version` was not synced during auto-release, causing it to fall out of sync on every release. Added step to update it alongside `package.json` and `plugin.json`. (#20)

## [0.6.7] - 2026-06-11

### Fixed

- **status.sh**: Python `IndentationError` on lines 97-98 — `mcps` variable had inconsistent 4-space indent in Python heredoc where surrounding code had 0-space indent. Changed to 0-space indent to resolve syntax error. (#19)
- **cli.js**: `findProjectRoot` started from package installation directory (npm cache) instead of user's working directory, causing `npx opencode-kit doctor/status/analytics` to fail in user projects. Changed to use `process.cwd()`. (#19)
- **cli.js**: `init` and `update` commands silently ignored when run via CLI (documented in `--help` but not in command map). Now shows a helpful message directing users to run the script directly. (#19)
- **init.sh**: `postflight.py` was not copied during scaffolding, causing `postflight.sh` to silently fall back in non-plugin mode. Added `postflight.py` copy alongside `postflight.sh`. (#19)
- **templates/contract.json**: `contract_version` was `0.6.4` while package was at `0.6.6`, causing the migration logic to trigger on every run. Synced to `0.6.6`. (#19)

### Added

- **package.json**: Added `npm test` script — runs `node test/integration.test.js && node test/e2e.test.js`. (#19)

### Changed

- **verify.sh**: Added `.opencode/src/postflight.py` to executable script check list. (#19)

## [0.6.6] - 2026-06-11

### Changed

- **rules.json**: Clarified graphify MCP description — explicitly states dependency on gitnexus index

## [0.6.5] - 2026-06-11

### Fixed

- **cli.js**: analytics command path was missing `.opencode/` prefix, causing silent fail
- **package.json**: lint script no longer suppresses shellcheck output with `2>/dev/null || true`
- **postflight.sh**: Reduced from 11 Python subprocesses to 1 via single eval call
- **rules/validation.sh**: Added missing `# shellcheck source=` directive
- **doctor.sh**: Guard against empty `check_cli` fields, use `shlex.split` instead of shell=True
- **templates/contract.json**: contract_version synced to 0.6.4 (stops false migration trigger)

### Added

- **CLI commands**: `npx opencode-kit doctor`, `status`, `analytics` — shortcuts to shell scripts from the CLI.
- **ESLint + Prettier config**: `.eslintrc.json` and `.prettierrc` for consistent JS formatting. Added `lint` and `format` npm scripts.
- **Contract JSON Schema**: `templates/contract.schema.json` — validates contract structure (state machine, required fields, score thresholds).
- **MCP connectivity check**: `doctor.sh` now tests actual MCP responsiveness (not just CLI existence).
- **Contract schema validation**: `doctor.sh` validates contract.json against the schema.
- **Performance**: Batched all `postflight.sh` Python invocations into a single `postflight.py` script (11 calls → 2 calls, 82% reduction).
- **Shell script tests**: `test/shell/test_basics.sh` with functional tests for all 15 shell scripts. Test runner at `test/shell/run.sh`.
- **Git hooks**: `.githooks/pre-commit` — prevents commits on `main`/`master`. `.githooks/commit-msg` — enforces conventional commit format. Both auto-configured via `init.sh`.
- **Rule overrides**: Plugin now reads `contract.json.validation.rule_overrides` and injects override context into agent bootstrap messages.

### Changed

- `src/postflight.sh` — refactored to use single Python script instead of 11 inline calls
- `src/init.sh` — now copies `.githooks/` and configures `core.hooksPath`
- `.opencode/plugins/opencode-kit.js` — rule override injection in bootstrap

## [0.6.4] - 2026-06-11

### Fixed
- global-config.sh: Use ${BASH_SOURCE[0]} instead of $0 for sourced context (H1)
- preflight.sh: Exit 1 when MCP validation fails instead of just warning (H2)
- postflight.sh: Replace pipe-delimited Python output with JSON field extraction (H3)

### Changed
- README: Fix "9 Built-in Skills" → "8 Built-in Skills", remove duplicate paragraph (H4)

## [0.6.0] - 2026-06-11

### Added

- **Automated release workflow**: `.github/workflows/release.yml` — on push to `main`, checks npm registry for version, runs tests, creates git tag, publishes to npm automatically.
- **NPM registry check**: Release workflow checks npm (not git tags) to decide whether to publish — prevents duplicate publish errors.

### Changed

- `package.json` — version 0.6.0
- `.claude-plugin/plugin.json` — version 0.6.0
- `RELEASE.md` — rewritten for automated CI/CD flow with manual-only PR + merge steps
- `CONTRIBUTING.md` — release section now points to CI/CD automation

### Fixed

- Release workflow used `npm ci` which requires `package-lock.json` — changed to `npm install`
- Remove unnecessary `git tag` check — replaced with direct npm registry lookup

## [0.5.9] - 2026-06-11

### Fixed

- **Critical: Plugin config hook crash** — Removed duplicate `const userSkillsDir` declaration in `plugin.js` that broke skills registration with `SyntaxError: Identifier 'userSkillsDir' has already been declared`. Config hook confirmed working post-fix.
- **Critical: E2E tests passing falsely** — Test harness did not await async functions, so all 9 E2E tests appeared to pass while silently swallowing rejections. Rewrote both integration and E2E test runners with proper collection + top-level await pattern.
- **Shell injection in ADR generator** — `src/adr.sh` interpolated user input directly into inline Python code via shell variables, allowing code injection via single quotes/backticks. Replaced with temp JSON file approach using Python's `json.load()`.
- **Plugin metadata version** — `.claude-plugin/plugin.json` was at `0.4.0` while `package.json` was at `0.5.8`. Synced to match.
- **Hardcoded init version** — `src/init.sh` displayed `v0.5.0` regardless of actual version. Now reads dynamically from `package.json`.
- **Dead code in status.sh** — Duplicate `required_mcps` variable computed but never used. Removed unused vars.
- **WRITE_001 severity mismatch** — Rule was `CRITICAL` severity with `FLAG` action (CRITICAL should map to BLOCK). Demoted to `HIGH` to match its actual action.
- **Invalid verdict constant** — Contract template used `PENDING` as verdict, which isn't in the state machine. Changed to `INIT`.
- **`bc` dependency removed** — `src/telemetry.sh` used `bc` for float arithmetic, unavailable on some Linux distros. Replaced with `$PYTHON_CMD`.
- **`.gitignore` missing state backup** — `.opencode/state/` created by `postflight.sh` was not gitignored.
- **`import assert` misplaced** — `test/e2e.test.js` had `import assert` at the bottom of the file after it was already used in tests. Moved to top with other imports.

## [0.5.0] - 2026-06-11

### Added

- **5 new skills**: `qa-expert` (test standards, edge cases, coverage), `system-analyst` (impact analysis, architecture checklist), `token-optimize` (reading strategy, batching, delegation anti-patterns), `verification-before-completion` (evidence rules, verification order), `learner` (post-execution learning, memory update matrix)
- **Auto-init contract**: Plugin auto-creates contract.json on first run via `ensureContract()`. Checks `~/.config/opencode-kit/` global config first, falls back to plugin template.
- **Contract uniqueness per project**: `getProjectHash()` generates unique lean-ctx key (`orchestration-contract:<sha256-hash>`) from git remote URL, with absolute path fallback.
- **Proper plugin logging**: Custom `log()` function writes to stderr instead of `console.log`. Wires up `client.log` API when available.
- **CLI version/help**: `src/cli.js` — `npx opencode-kit --version` / `--help`. Lists commands, plugin mode docs, config resolution chain.
- **Logo placeholder**: `docs/images/logo.svg` — simple SVG icon for README.
- **STATE.md auto-sync**: `postflight.sh` creates/updates STATE.md with current focus, known blockers, active ADRs, and recent changes from contract state.
- **Integration tests**: `test/integration.test.js` — 7 tests covering plugin loads, hooks, hash uniqueness, skills completeness, metadata validity, JSON validity. Added to CI workflow.
- **CI integration test job**: `.github/workflows/validate.yml` runs integration tests on Node.js 20.

### Changed

- `package.json` — version 0.5.0, `bin` points to `src/cli.js`
- `rules/rules.json` — simplified judge_prompt to avoid JSON escape issues
- `plugin.js` — major refactor: auto-init, project hash, proper logger, config resolution

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

[0.6.10]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.10
[0.6.9]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.9
[0.6.8]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.8
[0.6.7]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.7
[0.6.6]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.6
[0.6.5]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.5
[0.6.4]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.4
[0.6.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.6.0
[0.5.9]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.5.9
[0.5.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.5.0
[0.4.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.4.0
[0.3.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.3.0
[0.2.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.2.0
[0.1.0]: https://github.com/RizkiRachman/opencode-kit/releases/tag/v0.1.0
