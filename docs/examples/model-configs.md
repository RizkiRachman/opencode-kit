# Model Provider Configurations

Add these to your `opencode.json` to configure AI models for opencode-kit agents.

## DeepSeek (via Sumopod)

```json
{
  "model": "sumopod/deepseek-v4-flash",
  "provider": {
    "sumopod": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Sumopod AI",
      "options": {
        "baseURL": "https://ai.sumopod.com/v1",
        "apiKey": "sk-your-key"
      },
      "models": {
        "deepseek-v4-flash": {
          "name": "DeepSeek V4 Flash",
          "options": {
            "reasoningEffort": "high",
            "textVerbosity": "low"
          }
        }
      }
    }
  }
}
```

## OpenAI

```json
{
  "model": "gpt-4o",
  "provider": {
    "openai": {
      "npm": "@ai-sdk/openai",
      "models": {
        "gpt-4o": { "name": "GPT-4o" },
        "gpt-4o-mini": { "name": "GPT-4o Mini" }
      }
    }
  }
}
```

## Anthropic (Claude)

```json
{
  "model": "claude-sonnet-4-20250514",
  "provider": {
    "anthropic": {
      "npm": "@ai-sdk/anthropic",
      "models": {
        "claude-sonnet-4-20250514": { "name": "Claude Sonnet 4" },
        "claude-haiku-3-5-20241022": { "name": "Claude Haiku 3.5" }
      }
    }
  }
}
```

## Google (Gemini)

```json
{
  "model": "gemini-2.5-flash",
  "provider": {
    "google": {
      "npm": "@ai-sdk/google",
      "models": {
        "gemini-2.5-flash": { "name": "Gemini 2.5 Flash" },
        "gemini-2.5-pro": { "name": "Gemini 2.5 Pro" }
      }
    }
  }
}
```

## Agent Assignment Strategy

Use **cheaper models** for simple agents, **better models** for complex reasoning:

| Agent | Recommended Model | Why |
|-------|------------------|-----|
| orchestrator | Cheaper (orchestration, not deep thinking) | Delegates most work |
| planner | Better (architecture, impact analysis) | Needs deep reasoning |
| task-manager | Better (implementation, code quality) | Needs to write correct code |
| code-reviewer | Better (security, edge cases) | Needs sharp analysis |
| explorer | Cheaper (just searches) | Simple grep/glob |
| librarian | Cheaper (fetches docs) | Simple fetch operations |
| learner | Cheaper (analysis after the fact) | Post-processing only |
| fixer | Cheaper (bounded edits) | Well-defined scope |

Example with mixed models:

```json
{
  "agent": {
    "orchestrator": {
      "model": "sumopod/deepseek-v4-flash",
      "fallback_models": ["gpt-4o-mini"]
    },
    "planner": {
      "model": "gpt-4o",
      "fallback_models": ["sumopod/deepseek-v4-flash"]
    },
    "task-manager": {
      "model": "gpt-4o",
      "fallback_models": ["sumopod/deepseek-v4-flash"]
    }
  }
}
```
