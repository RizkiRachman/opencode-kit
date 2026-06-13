# Inheritance Model — opencode-kit Extension Architecture

## Concept

opencode-kit provides a **generic base**. Projects **extend** it like class inheritance:

```
opencode-kit (parent)
    ├── agents/                # base agent templates (15 agents)
    │   ├── orchestrator.md
    │   ├── planner.md
    │   └── ...
    ├── skills/                # base skill library (19 generic skills)
    │   ├── orchestration-template/
    │   ├── security-audit/
    │   └── ...
    ├── opencode.json.template # template → npm run build → opencode.json
    ├── rules/                 # base rules + workflow rules
    │   ├── rules.json
    │   ├── workflow-rules.json
    │   ├── agent-rules.json
    │   └── learner-rules.json
    └── contract.json          # base contract

Project (child extends parent)
    ├── .opencode/
    │   ├── agents/        # inherited + overridden agents
    │   ├── skills/        # inherited + custom skills
    │   ├── rules/         # inherited + custom rules + custom workflows
    │   │   ├── rules.json
    │   │   └── workflow-rules.json  # inherited + project-specific steps
    │   └── contract.json  # inherited + customized contract
    └── opencode.json      # project-specific config
```

## Extension Points

### 1. Contract Extension
```json
{
  "_meta": {
    "extends": "opencode-kit@1.0.0",
    "overrides": ["requirements.goal", "scope.boundary"]
  },
  "requirements": {
    "goal": "Project-specific goal (overrides base)"
  }
}
```

**Merge Rules:**
- Scalar values: project overrides base
- Arrays: project appends to base (deduplicated)
- Objects: deep merge (project wins conflicts)

### 2. Agent Extension
```json
{
  "_meta": {
    "extends": "orchestrator"
  },
  "skills": [
    "orchestration-template",  // inherited
    "custom-project-skill"     // appended
  ]
}
```

**Merge Rules:**
- Skills: appended (not replaced)
- Tools: merged (project wins)
- Model settings: project overrides

### 3. Rules Extension
```json
{
  "_meta": {
    "extends": "rules@1.0.0"
  },
  "rules": [
    // inherited rules...
    {
      "id": "CUSTOM_001",
      "severity": "HIGH",
      "desc": "Project-specific rule"
    }
  ]
}
```

**Merge Rules:**
- Rules: appended (not replaced)
- `required_mcps`: merged (project can add MCPs)
- Scoring thresholds: project overrides

### 4. Workflow Rules Extension
```json
{
  "_meta": {
    "extends": "opencode-kit",
    "appends": ["steps"]
  },
  "steps": [
    // inherited steps (context-load, explore, plan, execute, review, learn)
    {
      "id": "custom-deploy",
      "name": "Custom Deployment",
      "agent": "devops-agent",
      "phase": "COMPLETE",
      "inputs": ["code_changes"],
      "outputs": ["deployment_status"],
      "dependencies": ["code-review"],
      "validation": {
        "required": ["deploy_success"],
        "checks": ["health_check_pass"]
      }
    }
  ]
}
```

**Merge Rules:**
- Steps: appended (not replaced)
- Scoring thresholds: project overrides
- Validation rules: merged

### 4. Skills Extension
```
.opencode/skills/
├── (inherited from opencode-kit)
├── adr-generator/
├── codemap/
├── ... (19 base skills)
└── project-custom-skill/    # project adds this
    └── SKILL.md
```

**Merge Rules:**
- Base skills: copied during init
- Project skills: added in `.opencode/skills/`
- Name conflict: project skill wins

## Implementation

### `_meta` Field Schema
```json
{
  "_meta": {
    "extends": "string",      // parent identifier
    "version": "string",      // parent version
    "overrides": ["string"],  // overridden field paths
    "appends": ["string"],    // appended field paths
    "excludes": ["string"]    // excluded inherited items
  }
}
```

### Merge Algorithm
```
function merge(base, project):
  result = copy(base)
  
  for each key in project:
    if project[key] has _meta.extends:
      result[key] = merge(base[key], project[key])
    else if is_array(result[key]):
      result[key] = dedupe(result[key] + project[key])
    else if is_object(result[key]):
      result[key] = merge(result[key], project[key])
    else:
      result[key] = project[key]  // scalar override
  
  return result
```

## Usage Examples

### Example 1: Project adds custom skill
```bash
# After init, project adds:
.opencode/skills/my-api-client/SKILL.md

# In opencode.json, reference it:
"skills": ["orchestration-template", "my-api-client"]
```

### Example 2: Project overrides agent behavior
```json
// .opencode/agents/orchestrator.md
// Inherits base orchestrator, but adds project-specific instructions
```

### Example 3: Project adds custom rule
```json
// .opencode/rules/rules.json
{
  "_meta": { "extends": "opencode-kit" },
  "rules": [
    // ... inherited rules ...
    {
      "id": "PROJECT_001",
      "severity": "CRITICAL",
      "desc": "All API calls must use auth middleware"
    }
  ]
}
```

## Benefits

1. **DRY**: Don't repeat base configuration
2. **Upgradeable**: Update opencode-kit, project keeps customizations
3. **Composable**: Mix multiple extensions
4. **Type-safe**: Schema validates merged output
