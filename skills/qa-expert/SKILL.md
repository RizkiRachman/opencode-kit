---
description: Quality assurance — test strategy, coverage analysis, edge case detection, regression prevention.
---

# QA Expert

## Test Standards

- **One assertion per test** — each test validates exactly one behavior
- **Cover all branches** — happy path, empty, null, boundary, error
- **Test alongside code** — write tests in same phase as implementation, not after

## Edge Cases to Check

- Null/empty inputs for every param
- Boundary values (max length, pagination limits, date ranges)
- Concurrent access (if shared state exists)
- Timeout failures, network retries
- Malformed data (bad JSON, wrong types)

## Coverage Goals

- Domain services: ≥ 95% instruction coverage
- Adapters (web/persistence): ≥ 85%
- Mappers: ≥ 100% (trivial mappings can still break)
- Overall project: ≥ 90%
