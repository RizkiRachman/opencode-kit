# Quickstart: Using opencode-kit as a Plugin

This guide creates a new project from scratch with opencode-kit as an OpenCode plugin.

## Step 1: Create a project

```sh
mkdir my-agent-project
cd my-agent-project
git init
```

## Step 2: Install the plugin

```sh
npm install @ikieaneh/opencode-kit
```

## Step 3: Configure OpenCode

Create `opencode.json`:

```json
{
  "model": "your-model",
  "plugin": [
    "@ikieaneh/opencode-kit",
    "superpowers"
  ],
  "agent": {
    "orchestrator": {
      "model": "your-model",
      "skills": [
        "orchestration-template",
        "scoring-pipeline",
        "verification-before-completion"
      ],
      "steps": 50,
      "fallback_models": ["your-fallback-model"]
    },
    "planner": {
      "model": "your-model",
      "skills": ["brainstorming", "writing-plans", "system-analyst"],
      "steps": 80,
      "fallback_models": ["your-fallback-model"]
    },
    "task-manager": {
      "model": "your-model",
      "skills": ["subagent-driven-development", "executing-plans", "test-driven-development"],
      "steps": 100,
      "fallback_models": ["your-fallback-model"]
    },
    "code-reviewer": {
      "model": "your-model",
      "skills": ["qa-expert", "security-expert"],
      "steps": 80,
      "fallback_models": ["your-fallback-model"]
    },
    "explorer": {
      "model": "your-model",
      "steps": 30,
      "tools": { "postgres_*": false, "memory_*": false, "context7_*": false }
    },
    "librarian": {
      "model": "your-model",
      "steps": 30,
      "tools": { "postgres_*": false, "memory_*": false, "graphify_*": false }
    },
    "leaner": {
      "model": "your-model",
      "skills": ["verification-before-completion", "qa-expert"]
    }
  }
}
```

## Step 4: Start working

Open the project in OpenCode. The plugin auto-loads:

1. 8 skills registered automatically
2. Orchestration contract injected into every session
3. Pre-flight enforcement active (branch check, contract load)
4. Scoring pipeline available after every delegation
5. ADR generator for architectural decisions
6. Telemetry tracking elapsed time per phase

## Step 5: Set a goal

Edit `.opencode/orchestration/contract.json`:

```json
{
  "state": "INIT",
  "requirements": {
    "goal": "Add user authentication with JWT",
    "acceptance_criteria": ["Users can register", "Users can login", "Tokens expire after 24h"]
  }
}
```

## Step 6: Workflow runs itself

```
INIT → PLAN → PLAN_SCORED → EXECUTE → EXECUTE_SCORED → REVIEW → REVIEW_SCORED → COMPLETE
```

Each phase transition requires score ≥ 70. Score < 50 → BLOCKED.

## What you get

| Feature | Provider |
|---------|----------|
| Contract protocol | orchestration-template skill |
| Scoring pipeline | scoring-pipeline skill |
| ADR records | adr-generator skill |
| QA standards | qa-expert skill |
| Impact analysis | system-analyst skill |
| Token optimization | token-optimize skill |
| Verification gates | verification-before-completion skill |
| Post-task learning | learner skill |
| Telemetry | src/telemetry.sh |
| Rules enforcement | rules.json + validation.sh |
