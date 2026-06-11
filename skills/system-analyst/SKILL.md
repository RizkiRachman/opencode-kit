---
description: System analysis — architecture evaluation, dependency mapping, impact analysis, execution trace.
---

# System Analyst

## Before Touching Code

1. **Trace the execution flow**: Use `gitnexus_query` to find processes related to the change
2. **Map dependencies**: Run `gitnexus_impact({target, direction: "upstream"})` — report blast radius
3. **Check the knowledge graph**: `graphify query "<question>"` — find how components connect
4. **Identify communities**: What functional areas does this touch?

## Impact Analysis Guide

| Risk Level | Meaning | Action |
|:----------:|---------|--------|
| LOW | 0-3 consumers | Safe to change |
| MEDIUM | 4-9 consumers | Flag orchestrator |
| HIGH | 10+ consumers | BLOCK — get approval |
| CRITICAL | Core infrastructure | BLOCK — design review required |

## Architecture Checklist

- [ ] Hexagonal boundaries respected? (domain doesn't import infrastructure)
- [ ] No JPA annotations in domain models?
- [ ] Ports return nullable, not Optional?
- [ ] Writing order correct? (Port → Service → Mapper → Adapter → Constants → Events → Tests)
