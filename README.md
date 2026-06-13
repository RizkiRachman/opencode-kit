<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->
<div align="center">

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![npm][npm-shield]][npm-url]
[![PRs Welcome][prs-shield]][prs-url]

</div>

<!-- PROJECT HEADER -->
<br />
<div align="center">
  <a href="https://github.com/RizkiRachman/opencode-kit">
    <img src="docs/images/logo.svg" alt="Logo" width="80" height="80">
  </a>

<h1 align="center">opencode-kit</h1>

  <p align="center">
    One plugin. Every project gets 15 agents, 39 skills, 15 slash commands, 5 MCPs, and contract-based orchestration — automatically.
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=bug">Report Bug</a>
    ·
    <a href="https://github.com/RizkiRachman/opencode-kit/issues/new?labels=enhancement">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#built-with">Built With</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#architecture">Architecture</a></li>
    <li><a href="#agents--skills">Agents & Skills</a></li>
    <li><a href="#how-it-works">How It Works</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

---

<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://github.com/RizkiRachman/opencode-kit)

AI coding agents are powerful but **inconsistent**. Without structure, they skip conventions, ignore shared state, bypass quality gates, and use different approaches every run.

`opencode-kit` is an OpenCode plugin that replaces prose conventions with **machine-readable enforcement**. Install the plugin once, and every project session gets:

- **15 agents** — orchestrator, planner, code-reviewer, and more
- **39 skills** — orchestration, firecrawl, gitnexus, TDD, debugging
- **15 slash commands** — doctor, status, preflight, ADR, and more
- **5 MCPs** — lean-ctx, gitnexus, context7, firecrawl, github
- **ADR reports** — Architecture Decision Records for every decision
- **Session summaries** — auto-persisted state and lessons learned

All from a single plugin reference in `opencode.json`. Zero manual setup.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- BUILT WITH -->
## Built With

| Technology | Purpose |
|:-----------|:--------|
| **[Node.js](https://nodejs.org/)** | Runtime and plugin system |
| **[OpenCode](https://opencode.ai/)** | AI coding agent platform |
| **[lean-ctx](https://github.com/RizkiRachman/lean-ctx)** | Token-compressed file/shell gateway |
| **[graphify](https://github.com/RizkiRachman/graphify)** | Codebase graph intelligence |
| **[GitNexus](https://github.com/RizkiRachman/gitnexus)** | Code intelligence and impact analysis |

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

- **Node.js** >= 18
- **Git**
- **OpenCode** installed and configured

```sh
node --version    # >= 18
git --version     # any recent version
```

### Installation

**Step 1: Install globally (one-time)**

```sh
npm install -g @ikieaneh/opencode-kit
```

**Step 2: Add plugin to your project**

Add to your project's `opencode.json`:

```json
{
  "plugin": ["@ikieaneh/opencode-kit"]
}
```

That's it. Open your project in OpenCode — the plugin handles everything else.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE -->
## Usage

On first load, the plugin auto-provisions your project:

```
opencode.json:   "plugin": ["@ikieaneh/opencode-kit"]
     ↓ (first open)
Plugin writes to opencode.json:
  • 15 agent configs (skills + tools)
  • 15 slash command configs
  • 5 MCP server configs
  • 18 permission configs
Plugin provisions .opencode/:
  • agents/     → 15 agent .md templates
  • skills/     → 39 skill directories
  • rules/      → 7 rule files
  • orchestration/ → contract.json
Plugin registers tui.json:
  • @ikieaneh/opencode-kit/tui (auto-registered)
     ↓
Everything ready — 15 slash commands available
```

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

<!-- ARCHITECTURE -->
## Architecture

### File Structure

```
opencode-kit/
├── opencode.json.template    # Framework config (no model/provider)
├── AGENTS.md                 # Agent instructions
├── contract.json             # Contract template
├── contract.schema.json      # Contract schema
├── agents/                   # 15 agent templates
│   ├── orchestrator.md
│   ├── planner.md
│   ├── code-reviewer.md
│   ├── task-manager.md
│   ├── explorer.md
│   ├── librarian.md
│   ├── architect.md
│   ├── fixer.md
│   ├── learner.md
│   ├── observer.md
│   ├── database-specialist.md
│   ├── devops-agent.md
│   ├── documentation-agent.md
│   ├── security-reviewer.md
│   └── testing-specialist.md
├── skills/                   # 39 skills (65 dirs)
├── rules/                    # 7 rule files
├── src/                      # 22 shell scripts
├── docs/                     # Architecture docs
├── adr/                      # ADR templates
└── package.json
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
|:------|:-----------|:--------|
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

<!-- AGENTS & SKILLS -->
## Agents & Skills

### 15 Agents

| Agent | Purpose | Key Skills |
|:------|:--------|:-----------|
| `orchestrator` | Delegates, validates, drives state machine | orchestration-template, dispatching-parallel-agents |
| `planner` | Analyzes requests, traces impact, produces plans | writing-plans, executing-plans |
| `task-manager` | Breaks plans into tasks, implements each step | subagent-driven-dev, test-driven-dev |
| `code-reviewer` | Read-only code review — quality, security, performance | receiving-code-review, requesting-code-review |
| `explorer` | Fast codebase search across the entire project | gitnexus-exploring, firecrawl-search |
| `librarian` | Authoritative source for library docs and API references | firecrawl-scrape, firecrawl-knowledge-base |
| `architect` | Strategic technical advisor for high-stakes decisions | systematic-debugging, gitnexus-exploring |
| `fixer` | Fast implementation for well-defined bounded tasks | lean-ctx_* |
| `learner` | Post-execution learning — extracts lessons, persists knowledge | firecrawl-deep-research, firecrawl-knowledge-base |
| `observer` | System state monitor — read-only | firecrawl-scrape |
| `database-specialist` | Schema design, queries, migrations, optimization | db-design |
| `devops-agent` | CI/CD, deployment, infrastructure, automation | ci-cd, deployment |
| `documentation-agent` | Maintains README, API docs, inline documentation | firecrawl-scrape, firecrawl-knowledge-base |
| `security-reviewer` | Vulnerability assessment and security best practices | security-audit |
| `testing-specialist` | Unit tests, integration tests, test strategies | testing-strategies, test-driven-dev |

### 39 Skills

| Category | Skills |
|:---------|:-------|
| **Orchestration** | orchestration-template, orchestration-workflow, dispatching-parallel-agents, executing-plans, subagent-driven-dev |
| **Quality** | test-driven-dev, systematic-debugging, verification-before-completion, quality-checks, receiving-code-review, requesting-code-review, simplify |
| **Planning** | writing-plans, brainstorming, using-git-worktrees |
| **Web Research** | firecrawl-search, firecrawl-scrape, firecrawl-deep-research, firecrawl-knowledge-base, firecrawl-knowledge-ingest, firecrawl-map, firecrawl-qa, firecrawl-workflows |
| **Code Intelligence** | gitnexus-exploring, codemap, token-optimize |
| **Domain** | database-design, sql-optimization, ci-cd, deployment, infrastructure, security-audit, testing-strategies |
| **Learning** | learner, using-superpowers, system-analyst, scoring-pipeline, qa-expert |
| **Workflow** | adr-generator |

### 5 MCPs

| MCP | Purpose |
|:----|:--------|
| **lean-ctx** | Token-compressed file/shell gateway (mandatory) |
| **gitnexus** | Code intelligence and impact analysis |
| **context7** | Library documentation lookup |
| **firecrawl** | Web search, scraping, and interaction |
| **github** | GitHub API access |

Plus **graphify** (CLI tool, not MCP) for codebase graph intelligence.

### 15 Slash Commands

| Command | Description |
|:--------|:------------|
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

<!-- HOW IT WORKS -->
## How It Works

### 1. Plugin Auto-Provision

When OpenCode starts with `@ikieaneh/opencode-kit` in the plugin array, the plugin hook fires and provisions files from the package into `.opencode/`:

- `agents/` — 15 agent templates
- `skills/` — 39 skills
- `rules/` — 7 rule files
- `orchestration/contract.json`

### 2. Auto-Config

The plugin writes directly to the project's `opencode.json`:

- 15 agent configs (skills + tools)
- 15 slash command configs
- 5 MCP server configs
- 18 permission configs

Existing entries are preserved — never overwritten.

### 3. TUI Registration

The plugin auto-registers `@ikieaneh/opencode-kit/tui` in `tui.json` for slash command support in the OpenCode terminal UI.

### 4. MCP Availability Check

On startup, the plugin checks for required MCPs (`lean-ctx`, `gitnexus`, `graphify`) and warns if any are missing.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->
## Roadmap

- [x] Auto-provision agents, skills, rules
- [x] Auto-config opencode.json
- [x] ADR reports and session summaries
- [x] Task complexity detection
- [x] Graphify integration
- [x] MCP availability checks
- [x] Inheritance model with overrides and appends
- [x] Scoring pipeline (PASS/RETRY/BLOCKED)
- [ ] Multi-language agent support
- [ ] Web-based dashboard
- [ ] VS Code extension

See [ROADMAP.md](ROADMAP.md) for full details.

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

**RizkiRachman** — [GitHub](https://github.com/RizkiRachman)

Project Link: [https://github.com/RizkiRachman/opencode-kit](https://github.com/RizkiRachman/opencode-kit)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

- [Best-README-Template](https://github.com/othneildrew/Best-README-Template) — README structure
- [OpenCode](https://opencode.ai/) — AI coding agent platform
- [lean-ctx](https://github.com/RizkiRachman/lean-ctx) — Token-compressed gateway
- [graphify](https://github.com/RizkiRachman/graphify) — Codebase graph intelligence
- [GitNexus](https://github.com/RizkiRachman/gitnexus) — Code intelligence

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
[npm-shield]: https://img.shields.io/npm/v/@ikieaneh/opencode-kit.svg?style=for-the-badge&logo=npm
[npm-url]: https://www.npmjs.com/package/@ikieaneh/opencode-kit
[prs-shield]: https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge
[prs-url]: https://github.com/RizkiRachman/opencode-kit/pulls
[product-screenshot]: docs/images/screenshot.png