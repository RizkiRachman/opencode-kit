---
description: Java/Spring Boot conventions for opencode-kit projects. Hexagonal architecture, ArchUnit, Maven build.
---

# Java Developer

Load this skill if your project uses **Java + Spring Boot + Maven**.

## Build & Test

Replace generic `npm` commands with Maven equivalents:

| Generic | Java Equivalent |
|---------|-----------------|
| `npm test` | `mvn test` |
| `npm run build` | `mvn compile` |
| `npm run format` | `mvn spotless:apply` |
| `npm test -- --all` | `mvn verify` |

## Quality Gates (run in order)

```sh
mvn spotless:apply        # Formatting (Google Java Style)
mvn test                  # ArchUnit (7 rules) + unit tests
mvn verify                # SpotBugs + PMD CPD + full tests
```

## Agent Permission Overrides

In `opencode.json`, add Maven permissions to agents:

```json
"bash": {
  "mvn test*": "allow",
  "mvn compile*": "allow",
  "mvn verify": "allow",
  "mvn spotless:apply": "allow",
  "git diff*": "allow",
  "git log*": "allow"
}
```

## Conventions

### Hexagonal Architecture
```
application/       → domain model, ports, domain services
infrastructure/    → web adapters, persistence, event handlers
```

### Writing Order
Port → Service → Mapper → Adapter → Constants → Events → Tests

### Domain Models
- `@Builder @Getter @Setter` — zero JPA annotations
- Ports return **nullable**, never `Optional<T>`
- No JPA relationship annotations (`@ManyToOne`, `@OneToMany`, etc.)

### ArchUnit Rules (7)
1. domainMustNotDependOnInfrastructure
2. domainModelsMustNotHaveJpaAnnotations
3. portsMustNotReturnOptional
4. entitiesMustNotUseJpaRelationshipAnnotations
5. layeredArchitectureShouldRespectHexagonalBoundaries
6. domainServicesMustBeAnnotatedWithService
7. repositoryAdaptersMustBeAnnotatedWithComponent
