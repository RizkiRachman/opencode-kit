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
    <img src="docs/images/logo.svg" alt="Logo" width="80" height="80">
  </a>

<h3 align="center">opencode-kit</h3>

  <p align="center">
    Plugin that auto-provisions agents, skills, rules, and configs for OpenCode. Zero-config — just add the plugin.
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=enhancement">Request Feature</a>
  </p>

  <p>
    <b>npm:</b> <code>@ikieaneh/opencode-kit</code> &middot;
    <b>Cross-platform</b> — macOS, Linux, Windows
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
        <li><a href="#verification">Verification</a></li>
      </ul>
    </li>
    <li><a href="#how-it-works">How It Works</a></li>
    <li><a href="#structure">Structure</a></li>
    <li><a href="#enforcement-system">Enforcement System</a></li>
    <li><a href="#agents--skills">Agents & Skills</a></li>
    <li><a href="#slash-commands">Slash Commands</a></li>
    <li><a href="#known-limitations">Known Limitations</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->
## About

`opencode-kit` is an OpenCode **plugin** that auto-provisions a complete agent workflow framework. Install the plugin, and every session gets 15 agents, 39 skills, 7 rule files, 6 MCP configs, and 15 slash commands — automatically.

### The Problem

AI coding agents are powerful but **inconsistent**. Without structure, they:

- Skip conventions and jump to implementation
- Ignore shared state — each session starts fresh
- Bypass quality gates — no review, no scoring, no learning
- Use different approaches every run

### The Solution

`opencode-kit` replaces prose conventions with **machine-readable enforcement**. It injects a contract-based orchestration framework into every OpenCode session via a plugin hook — no manual setup required.

| Instead of ... | opencode-kit uses ... |
|:---------------|:----------------------|
| "read the state file" | `contract.json` — a JSON state machine agents MUST read/write |
| "follow the rules" | `rules.json` — CRITICAL rules BLOCK agents, HIGH rules FLAG them |
| "check before editing" | Pre-flight gate — fails if rules aren't met |
| "review your work" | Scoring pipeline — every output scored (≥70 PASS, <50 BLOCK) |
| "remember what you learned" | Auto-persisted state, telemetry, and lessons learned |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

- **Node.js** ≥ 18
- **Git**
- **OpenCode** installed
- MCP servers configured: `lean-ctx`, `gitnexus`, `context7`, `firecrawl`, `github`

```sh
node --version    # ≥ 18
git --version     # any recent version
```

### Installation

**Step 1: Install globally (one-time)**

```sh
npm install -g @ikieaneh/opencode-kit
```

**Step 2: Add to your project**

Create or edit `opencode.json` in your project root:

```json
{
  "plugin": ["@ikieaneh/opencode-kit"]
}
```

**Step 3: Open opencode — plugin initializes everything**

On first session, the plugin writes agent/command/MCP/permission configs directly to your `opencode.json` and auto-provisions `.opencode/` files:

```
opencode.json:   "plugin": ["@ikieaneh/opencode-kit"]
     ↓ (first open)
Plugin writes to opencode.json:
  • 15 agent configs (skills + tools)
  • 15 slash command configs
  • 6 MCP server configs
  • 18 permission configs
Plugin provisions .opencode/:
  • agents/ (15 .md files)
  • skills/ (39 skill dirs)
  • rules/ (7 rule files)
  • orchestration/contract.json
Plugin registers tui.json:
  • @ikieaneh/opencode-kit/tui (auto-registered)
     ↓
Everything ready — 15 slash commands available
```

> **Note**: Plugin writes to `opencode.json` on first load only. Existing entries are preserved — never overwritten.

### Verification

After installation, verify everything loaded:

```sh
npx opencode-kit doctor
```

Expected output:

```
✅ contract.json
✅ rules.json
✅ 15 agents provisioned
✅ 39 skills provisioned
✅ 7 rule files loaded
✅ All checks passed
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- HOW IT WORKS -->
## How It Works

### Plugin Auto-Provision Flow

When OpenCode starts with `@ikieaneh/opencode-kit` in the plugin array, the plugin hook fires and:

1. Auto-provisions files from the package:
   - `.opencode/agents/` — 15 agent templates
   - `.opencode/skills/` — 39 skills
   - `.opencode/rules/` — 7 rule files
   - `.opencode/orchestration/contract.json`
2. Writes configs directly to the project's `opencode.json`:
   - 15 agent configs (skills + tools)
   - 15 slash command configs
   - 6 MCP server configs
   - 18 permission configs
3. Auto-registers `@ikieaneh/opencode-kit/tui` in `tui.json` for slash commands

No manual copying. No wrapper scripts. Just install and go.

### What Projects Get

```
my-project/
├── .opencode/
│   ├── agents/       (auto-provisioned: 15 agents)
│   ├── skills/       (auto-provisioned: 39 skills)
│   ├── rules/        (auto-provisioned: 7 rule files)
│   ├── orchestration/ (auto-provisioned: contract.json)
│   └── plugins/      (plugin entry points)
```

### Inheritance Model

opencode-kit uses **class inheritance** — projects extend the base, not replace it.

```json
// Project's contract.json
{
  "_meta": {
    "extends": "opencode-kit",
    "overrides": ["requirements.goal"],
    "appends": ["scope.included"]
  },
  "requirements": {
    "goal": "Project-specific goal (overrides base)"
  }
}
```

| Layer | Extend Via | Example |
|-------|-----------|---------|
| **Contract** | `_meta.overrides` / `_meta.appends` | Override goal, append scope |
| **Agents** | `_meta.append_skills` | Add project-specific skills |
| **Rules** | `_meta.appends: ["rules"]` | Add custom rules |
| **Skills** | Add to `.opencode/skills/` | Create `my-api-client/SKILL.md` |

**Merge Rules:**
- Scalars: project overrides base
- Arrays: concatenated + deduplicated
- Objects: deep merged (project wins)
- Excludes: `_meta.excludes` removes inherited items

See [docs/inheritance-model.md](docs/inheritance-model.md) for full architecture.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- STRUCTURE -->
## Structure

```
opencode-kit/
├── opencode.json.template    # Framework config (no model/provider)
├── AGENTS.md                 # Agent instructions
├── contract.json             # Contract template
├── contract.schema.json      # Contract schema
├── agents/                   # 15 agent templates
├── skills/                   # 39 skills
├── rules/                    # 7 rule files
├── src/                      # 22 scripts
├── docs/                     # Architecture docs
├── .github/workflows/        # CI/CD
└── package.json
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ENFORCEMENT SYSTEM -->
## Enforcement System

### 1. Plugin Bootstrap

Every session auto-loads the orchestration contract before any work begins.

### 2. Pre-flight Gate

Validates branch, contract state, and rule compliance. BLOCKs on CRITICAL violations. Includes state machine validation (transition legality, required fields).

### 3. Contract Protocol

Shared state machine (`contract.json`) tracks phase, decisions, scores, and telemetry. Every agent reads and writes to the contract.

### 4. Scoring Pipeline

Every subagent output is scored on a 0-100 scale:
- **≥70** → PASS, advance to next phase
- **50-69** → RETRY (up to 3 attempts)
- **<50** → BLOCKED (escalate to user)

### 5. Audit Trail

JSONL compliance logging records every enforcement action, score, and phase transition for later analysis.

### 6. ADR Logging

Every architectural decision recorded in `decisions.adr_log[]` with structured format.

### 7. Extension Model

Project-specific skills in `.opencode/skills/` override plugin defaults via `_meta.extends`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- AGENTS & SKILLS -->
## Agents & Skills

### 15 Agents

| Agent | Role |
|-------|------|
| `orchestrator` | Coordinates multi-agent workflows, manages task delegation |
| `planner` | Analyzes requests, traces impact, produces implementation plans |
| `task-manager` | Breaks plans into tasks, implements each step |
| `code-reviewer` | Read-only code review — quality, security, performance |
| `explorer` | Fast codebase search specialist |
| `librarian` | Authoritative source for library docs and API references |
| `architect` | Strategic technical advisor for high-stakes decisions |
| `fixer` | Fast implementation specialist for well-defined bounded tasks |
| `learner` | Post-execution learning agent — extracts lessons, persists knowledge |
| `observer` | System state monitor and reporter — read-only |
| `database-specialist` | Database schema design, queries, migrations, optimization |
| `devops-agent` | CI/CD, deployment, infrastructure, automation |
| `documentation-agent` | Maintains README, API docs, inline documentation |
| `security-reviewer` | Vulnerability assessment and security best practices |
| `testing-specialist` | Unit tests, integration tests, test strategies |

### 39 Skills

Skills provide specialized instructions and workflows for specific tasks. Highlights include:

- **orchestration-workflow** — Contract protocol, state machine, persistence rules
- **firecrawl-\*** — Web search, scraping, interaction, monitoring (15 skills)
- **superpowers** — brainstorming, TDD, debugging, code review, parallel agents, and more
- **gitnexus-\*** — Code intelligence, impact analysis, debugging, refactoring
- **quality-checks** — Linting, formatting, static analysis
- **testing-strategies** — Test planning and coverage

Full list: see `skills/` directory or load via the `skill` tool in OpenCode.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- SLASH COMMANDS -->
## Slash Commands

All 15 commands available in the OpenCode TUI:

| Command | Description |
|---------|-------------|
| `/opencode-kit:doctor` | Run project health checks |
| `/opencode-kit:status` | Show project status |
| `/opencode-kit:analytics` | Show project analytics |
| `/opencode-kit:preflight` | Run pre-flight gate checks |
| `/opencode-kit:score` | Run scoring pipeline |
| `/opencode-kit:contract-lint` | Validate contract structure |
| `/opencode-kit:checkpoint` | List saved checkpoints |
| `/opencode-kit:checkpoint-save` | Save a checkpoint |
| `/opencode-kit:diff` | Show contract changes |
| `/opencode-kit:audit` | Query audit trail |
| `/opencode-kit:verify` | Verify project setup |
| `/opencode-kit:lock` | Check contract lock status |
| `/opencode-kit:init` | Initialize opencode-kit |
| `/opencode-kit:update` | Update templates |
| `/opencode-kit:adr` | Create Architecture Decision Record |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- KNOWN LIMITATIONS -->
## Known Limitations

- **Plugin hook API**: The `experimental.chat.messages.transform` hook is marked experimental in the OpenCode plugin SDK. If it breaks, the plugin falls back to per-project agent `.md` files, which remain functional.
- **TUI plugin**: The TUI plugin is auto-registered by the main kit plugin. Requires OpenCode with TUI support. Scripts run synchronously via `execSync` — long-running scripts may block the UI temporarily.
- **Contract auto-init**: Requires a git repository. Non-git projects use absolute path as hash fallback.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->
## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

Fork → Feature branch → Commit → PR. Follow the enforcement architecture. All rule enforcements must be tested.

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