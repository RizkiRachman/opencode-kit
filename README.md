<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<br />
<div align="center">
  <a href="https://github.com/RizkiRachman/opencode-kit">
    <img src="docs/images/logo.png" alt="Logo" width="80" height="80">
  </a>

<h3 align="center">opencode-kit</h3>

  <p align="center">
    Standardized OpenCode orchestration framework — contract-based, rules-enforced, zero-touch agent workflow
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=enhancement">Request Feature</a>
  </p>

  <p>
    <b>macOS M-Series</b> — Apple Silicon (arm64)
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#philosophy">Philosophy</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#structure">Structure</a></li>
    <li><a href="#the-6-pillars">The 6 Pillars</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About The Project

`opencode-kit` is a portable orchestration framework for OpenCode-based AI agents. It solves one core problem:

**Agents skip the workflow and jump straight to implementation.**

Traditional agent frameworks use conventions (".md files say to load state first") but agents routinely bypass them because there's no enforcement. `opencode-kit` makes the workflow **machine-enforced**, not convention-based.

### How it works

1. **`contract.json`** — shared state machine every agent MUST read/write
2. **`rules.json`** — machine-readable rules with CRITICAL/HIGH/LOW severity
3. **`preflight.sh`** — enforcement gate that BLOCKs agents that skip the contract
4. **`postflight.sh`** — auto-persists state + runs scoring pipeline

The result: zero-touch agent workflow. Set a goal, and the system self-executes through Plan → Build → Review → Learn, pausing only when BLOCKED.

### Built for macOS M-Series

Developed and tested on Apple Silicon (M1/M2/M3/M4). All scripts use portable POSIX shell with zero Linux-specific dependencies.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- PHILOSOPHY -->
## Philosophy

### Data-driven enforcement, not convention

Most agent frameworks say "please load the envelope first" in prose. Agents ignore prose. `opencode-kit` stores rules as JSON and validates them with shell scripts — the agent can't work around a failing `preflight.sh`.

### Contract over envelope

The shared state is called a **contract**, not an envelope. A contract is legally binding — every agent agrees to its terms. Breaking the contract is a governance violation, not a suggestion.

### Score or fail

Every subagent output is scored on a 0-100 scale:
- **≥70** → PASS, advance to next phase
- **50-69** → RETRY (up to 3 attempts)
- **<50** → BLOCKED (escalate to user)

This creates a quality floor that cheap models can meet through architecture, not raw intelligence.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

- **macOS** on Apple Silicon (M1, M2, M3, or M4)
- **Node.js** ≥ 18 (for `npx` support)
- **Git** (for version control)
- **OpenCode** with the following MCPs configured:
  - `lean-ctx` (context persistence)
  - `gitnexus` (code intelligence)
  - `graphify` (knowledge graph)

```sh
# Verify prerequisites
node --version    # ≥ 18
git --version     # any recent version
```

### Installation

#### Option 1: Quick start (recommended)

```sh
npx opencode-kit init
```

This scaffolds the full framework into your current project directory.

#### Option 2: From source

```sh
git clone https://github.com/RizkiRachman/opencode-kit.git
cd your-project
/path/to/opencode-kit/src/init.sh
```

### Post-install verification

```sh
.opencode/src/verify.sh
```

Expected output:
```
✅ contract.json
✅ rules.json
✅ agents/orchestrator.md (has pre-flight gate)
✅ agents/planner.md (has pre-flight gate)
...
✅ All checks passed
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE -->
## Usage

### 1. Set a goal

Edit `.opencode/orchestration/contract.json`:

```json
{
  "state": "INIT",
  "requirements": {
    "goal": "Add user authentication with JWT",
    "acceptance_criteria": [
      "Users can register with email + password",
      "Users can login and receive a JWT token",
      "Tokens expire after 24 hours"
    ],
    "constraints": ["No new dependencies", "Follow hexagonal architecture"]
  }
}
```

### 2. Start working

Every agent session automatically:

1. **Loads the contract** (BLOCKED if missing)
2. **Validates branch** (BLOCKED if on main)
3. **Validates state** (BLOCKED if wrong phase)
4. **Checks rules** (CRITICAL violations = BLOCK)

### 3. The workflow runs itself

```
INIT → PLAN → PLAN_SCORED → EXECUTE → EXECUTE_SCORED → REVIEW → REVIEW_SCORED → COMPLETE
                                        ↓
                                     BLOCKED ← user intervention → retry
```

Each phase transition requires a score ≥70 to proceed.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- STRUCTURE -->
## Structure

```
opencode-kit/
 ├── rules/
 │   ├── rules.json              ← Machine-enforceable rules (CRITICAL/HIGH/state machine)
 │   └── validation.sh           ← Validates agent actions against rules (future)
 ├── src/
 │   ├── init.sh                 ← Scaffold into target project
 │   ├── preflight.sh            ← Envelope load gate (zero deps, fails if rules violated)
 │   ├── postflight.sh           ← Auto-persist + scoring pipeline
 │   └── verify.sh               ← Installation health check
 ├── templates/
 │   ├── contract.json           ← Shared state contract (renamed from "envelope")
 │   ├── superpowers-contract.json
 │   └── agents/
 │       ├── orchestrator.md
 │       ├── planner.md
 │       ├── task-manager.md
 │       ├── code-reviewer.md
 │       ├── learner.md
 │       └── fixer.md
 ├── package.json                ← npm publish for `npx opencode-kit init`
 └── README.md                   ← You are here
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- THE 6 PILLARS -->
## The 6 Pillars

### 1. GitNexus — Code Intelligence

**Rule**: `IMPACT_001` — CRITICAL. Agent MUST run `gitnexus_impact` before editing any symbol.

```sh
# Before touching any code:
gitnexus_impact({target: "symbolName", direction: "upstream"})
# If HIGH/CRITICAL risk → BLOCK, report to user
```

### 2. Graphify — Knowledge Graph

**Rule**: Agents MUST explore unfamiliar code via graph queries, not linear file reads.

```sh
graphify query "<question>"     # Scoped subgraph exploration
```

### 3. Lean Ctx — Context Persistence

**Rule**: `PERSIST_001` — HIGH. Contract MUST be persisted after every delegation/phase change.

```sh
lean-ctx ctx_knowledge remember key orchestration-contract value <updated JSON>
```

### 4. Workflow State — State Machine

**Rule**: `STATE_001` — CRITICAL. Agents can only act in correct state.

```json
{
  "transitions": [
    { "from": "INIT", "to": "PLAN" },
    { "from": "PLAN", "to": "PLAN_SCORED" },
    { "from": "PLAN_SCORED", "to": "EXECUTE", "require_score": 70 },
    ...
    { "from": "*", "to": "BLOCKED", "condition": "score < 50 OR attempts >= 3" }
  ]
}
```

### 5. ADR — Architecture Decision Records

Every decision is logged in `contract.json.decisions.adr_log[]` with structured format:

```json
{
  "decisions": {
    "adr_log": [
      { "id": "ADR-001", "date": "2026-06-11", "title": "Orchestration framework",
        "context": "Agents bypassed envelope protocol", "decision": "Switch to contract + rules.json",
        "alternatives": ["Keep envelope", "Use script enforcement"],
        "consequences": "Stronger enforcement, more scaffolding on init" }
    ]
  }
}
```

### 6. Scoring — Quality Pipeline

After every subagent delegation, scoring runs automatically:
1. **Tier 1** — Rule-based checks (schema valid, permissions OK, blast radius safe)
2. **Tier 2** — LLM judge (fulfills requirements? follows governance? complete?)
3. **Tier 3** — Combined verdict (PASS/RETRY/BLOCKED)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

### v0.1 (current POC)
- [x] GitHub repo structure
- [x] `contract.json` — shared state machine
- [x] `rules.json` — 8 enforcement rules
- [x] `preflight.sh` — load contract, validate branch, check state
- [x] `postflight.sh` — persist contract, run scoring
- [x] `init.sh` — scaffold into target project
- [x] `verify.sh` — installation health check
- [x] 6 agent .md templates with embedded pre-flight gates
- [x] npm package.json for `npx opencode-kit init`

### v0.2 — Hardening
- [ ] Auto-detect MCP availability (lean-ctx, gitnexus, graphify)
- [ ] `rules/validation.sh` — validate agent actions against rules
- [ ] Test on clean macOS M-series machine
- [ ] Edge cases: re-init over existing `.opencode/`
- [ ] ADR auto-generate on decision

### v0.3 — Production
- [ ] Cross-platform (Linux, Intel Mac)
- [ ] GitHub Actions CI
- [ ] `opencode-kit update` — pull latest templates
- [ ] Scoring Tier 2 (LLM judge) auto-integration
- [ ] Telemetry: track cost/elapsed per phase

### Future
- [ ] Plugin system for custom rules
- [ ] Web UI for contract overview
- [ ] Multi-repo orchestration (monorepo support)

See the [open issues](https://github.com/RizkiRachman/opencode-kit/issues) for full list.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

TL;DR: Fork → Feature branch → Commit → PR. Follow the 6-pillar architecture. All rules enforcements must be tested.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->
## Contact

Rizki Rachman — [GitHub](https://github.com/RizkiRachman)

Project Link: [https://github.com/RizkiRachman/opencode-kit](https://github.com/RizkiRachman/opencode-kit)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/RizkiRachman/opencode-kit.svg?style=for-the-badge
[contributors-url]: https://github.com/RizkiRachman/opencode-kit/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/RizkiRachman/opencode-kit.svg?style=for-the-badge
[forks-url]: https://github.com/RizkiRachman/opencode-kit/network/members
[stars-shield]: https://img.shields.io/github/stars/RizkiRachman/opencode-kit.svg?style=for-the-badge
[stars-url]: https://github.com/RizkiRachman/opencode-kit/stargazers
[issues-shield]: https://img.shields.io/github/issues/RizkiRachman/opencode-kit.svg?style=for-the-badge
[issues-url]: https://github.com/RizkiRachman/opencode-kit/issues
[license-shield]: https://img.shields.io/github/license/RizkiRachman/opencode-kit.svg?style=for-the-badge
[license-url]: https://github.com/RizkiRachman/opencode-kit/blob/main/LICENSE
