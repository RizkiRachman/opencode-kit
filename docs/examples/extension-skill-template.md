# Extension Skill Template

Create project-specific skills in `.opencode/skills/` to extend opencode-kit.

## Resolution Order

1. `.opencode/skills/<name>/SKILL.md` — user project skill (highest priority)
2. `node_modules/@ikieaneh/opencode-kit/skills/<name>/SKILL.md` — plugin skill (fallback)

If a user skill and plugin skill have the **same name**, the user's version takes priority.

## Example: Java/Spring Conventions

Create `.opencode/skills/java-conventions/SKILL.md`:

```markdown
---
description: Java 21 + Spring Boot 3.4 conventions for this project.
---

# Java Conventions

## Build & Test

| Command | Action |
|---------|--------|
| `mvn spotless:apply` | Format (Google Java Style) |
| `mvn test` | ArchUnit + unit tests |
| `mvn verify` | SpotBugs + PMD CPD |

## Hexagonal Architecture

```
application/      → domain model, ports, services (no Spring/JPA)
infrastructure/   → web adapters, persistence, events
```

## Writing Order

Port → Service → Mapper → Adapter → Constants → Events → Tests

## Naming Rules

| Concern | Suffix | Example |
|---------|--------|---------|
| API DTO | none | `Product` |
| Domain Model | `Domain` | `ProductDomain` |
| JPA Entity | `Entity` | `ProductEntity` |

## ArchUnit Rules (7)

1. domainMustNotDependOnInfrastructure
2. domainModelsMustNotHaveJpaAnnotations
3. portsMustNotReturnOptional
4. entitiesMustNotUseJpaRelationshipAnnotations
5. layeredArchitectureShouldRespectHexagonalBoundaries
6. domainServicesMustBeAnnotatedWithService
7. repositoryAdaptersMustBeAnnotatedWithComponent
```

## Example: Python/Django Conventions

Create `.opencode/skills/python-conventions/SKILL.md`:

```markdown
---
description: Django REST Framework conventions for this project.
---

# Python Conventions

## Build & Test

| Command | Action |
|---------|--------|
| `black .` | Format code |
| `ruff check .` | Lint |
| `pytest` | Run tests |
| `mypy .` | Type check |

## Architecture

Apps follow clean architecture:
- `models/` — domain models with business logic
- `serializers/` — input/output validation
- `views/` — HTTP handlers (thin)
- `services/` — business logic layer
- `tests/` — mirrors app structure
```

## How to Load

In `opencode.json`, add to any agent's skills array:

```json
{
  "agent": {
    "task-manager": {
      "skills": [
        "verification-before-completion",
        "java-conventions"
      ]
    }
  }
}
```

Or load it ad-hoc with: `/skill java-conventions`
