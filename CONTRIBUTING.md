# Contributing to opencode-kit

First off, thanks for taking the time to contribute! 🎉

## Code of Conduct

This project is governed by a simple rule: **be excellent to each other**. Harassment, trolling, and disrespectful behavior will not be tolerated.

## How to Contribute

### Reporting Bugs

Open an issue with the `bug` label. Include:
- macOS version + chip (M1/M2/M3/M4)
- Node.js version
- Steps to reproduce
- Expected vs actual behavior

### Suggesting Features

Open an issue with the `enhancement` label. Include:
- What problem it solves
- How it fits the 6-pillar architecture
- Any trade-offs or alternatives considered

### Pull Requests

1. Fork the repo
2. Create your feature branch:
   ```sh
   git checkout -b feature/YYYYMMDD-description
   ```
3. Make your changes
4. Test on macOS M-series:
   ```sh
   # For scripts: manually run against a test project
   /path/to/opencode-kit/src/init.sh --force
   /path/to/opencode-kit/src/verify.sh
   ```
5. Commit with descriptive message:
   ```sh
   git commit -m "feat: add X to support Y"
   ```
6. Push and open a PR

### Commit Convention

We follow conventional commits:

- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation
- `refactor:` — code restructure
- `test:` — adding tests
- `chore:` — maintenance

## Architecture Guidelines

### 6 Pillars

Every contribution should fit one or more of the 6 pillars:

| Pillar | Core File | Rule ID |
|--------|-----------|---------|
| GitNexus | `rules.json` | `IMPACT_001` |
| Graphify | `rules.json` | `EXPLORE_001` |
| Lean Ctx | `postflight.sh` | `PERSIST_001` |
| Workflow State | `contract.json` | `STATE_001` |
| ADR | `contract.json.decisions` | — |
| Scoring | `scoring-pipeline.sh` | `SCORE_001` |
| Contract Locking | `contract-lock.sh` | — |
| Adoption | `adoption-check.sh` | — |
| Audit Trail | `audit-trail.sh` | — |

### Rules First

- New enforcement rules go in `rules/rules.json` — NOT in agent .md files
- Each rule needs: `id`, `severity`, `description`, `condition`, `action`, `message`
- CRITICAL → BLOCK the agent. HIGH → FLAG orchestrator. LOW → advisory only.

### Agent Templates

- Every agent .md must open with the pre-flight gate as the FIRST instruction
- No prose before the pre-flight block
- The gate must reference `contract.json` and `rules.json`

### Scripts

- Must be portable POSIX shell (`/usr/bin/env bash`)
- Must use `which` for tool discovery (no hardcoded paths)
- Must test on macOS M-series before committing
- Must use `lean-ctx_*` tools for context persistence (never bash for context operations)
- Must follow contract state machine — never skip states
- Must log to audit trail for compliance

## Development Setup

```sh
git clone https://github.com/RizkiRachman/opencode-kit.git
cd opencode-kit
npm install    # installs dependencies if any

# Create a test project
mkdir -p /tmp/test-project && cd /tmp/test-project
git init
/path/to/opencode-kit/src/init.sh
/path/to/opencode-kit/src/verify.sh

# Verify new enforcement scripts
bash .opencode/src/adoption-check.sh
bash .opencode/src/scoring-pipeline.sh
bash .opencode/src/audit-trail.sh log test "setup" '{"test": true}'
bash .opencode/src/contract-lint.sh
```

## Enforcement Architecture

The project uses a 6-layer enforcement system to maintain consistency and compliance across all agent interactions:

- **Layer 1: Adoption check** — runs before anything to ensure the project is properly initialized
- **Layer 2: Pre-flight gate** — executes on every agent invocation to verify contract, rules, and schema validation
- **Layer 3: Contract locking** — prevents concurrent access conflicts via `contract-lock.sh`
- **Layer 4: Scoring pipeline** — evaluates agent behavior after each agent returns via `scoring-pipeline.sh`
- **Layer 5: Audit trail** — logs all compliance-relevant actions via `audit-trail.sh`
- **Layer 6: Agent templates** — pre-flight gates embedded in all 10 agent `.md` files

See [Enforcement Architecture](docs/guides/enforcement-architecture.md) for details.

## Release Process

**Releases are fully automated.** When a PR is merged to `main`, the `release` GitHub Actions workflow automatically:
1. Detects the new version from `package.json`
2. Runs tests (integration + E2E)
3. Creates a git tag `v<version>`
4. Publishes to npm (`@ikieaneh/opencode-kit`)

### What you need to do

**You never need to bump versions manually. The release workflow handles it automatically. Just merge your PR.**

### One-time setup for maintainers

The automation requires the `NPM_TOKEN` secret in GitHub repository settings:
- Generate an **Automation** token at https://www.npmjs.com/settings/<username>/tokens
- Add it as a repository secret: **Settings → Secrets and variables → Actions → New repository secret**
- Name: `NPM_TOKEN`, Value: your npm token

See [RELEASE.md](RELEASE.md) for full details.

## Questions?

Open a discussion or issue. We're happy to help!
