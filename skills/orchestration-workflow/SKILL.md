---
name: orchestration-workflow
description: Use when coordinating multi-agent workflows, managing task delegation, and tracking execution progress across specialist agents.
---

# Orchestration Workflow

## When to Use
- Coordinating multiple specialist agents
- Managing complex multi-step tasks
- Tracking task dependencies and progress

## Workflow
1. Parse user request into discrete tasks
2. Identify dependencies between tasks
3. Delegate to appropriate specialist agents
4. Track progress and handle failures
5. Synthesize results and report back

## Agent Selection
- Implementation tasks → @fixer
- Design tasks → @designer
- Research tasks → @librarian
- Review tasks → @oracle
- Exploration tasks → @explorer
