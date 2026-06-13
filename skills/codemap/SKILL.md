# Codemap — Codebase Structure Generator

**Generate hierarchical maps of unfamiliar codebases.**

## When to Use

- First time exploring a new codebase
- Need a high-level overview before diving in
- User asks "what is the structure of this project?"

## Workflow

### 1. Directory Tree
```bash
lean-ctx ctx_tree --depth 3
```

### 2. Key Files
```bash
lean-ctx ctx_search --pattern "^(export|module|class|function)" --ext ".ts,.js,.py"
```

### 3. Package Info
```bash
lean-ctx ctx_read --path "package.json"
lean-ctx ctx_read --path "README.md"
```

### 4. Build Map
Combine results into a structured overview:
- Entry points
- Module structure
- Key dependencies
- Configuration files

## Output Format

```markdown
## Project Structure
├── src/
│   ├── api/          # HTTP handlers
│   ├── services/     # Business logic
│   └── utils/        # Helpers
├── tests/
└── config/
```

## Tips

- Start broad (tree), then narrow (search)
- Focus on entry points and exports
- Note framework patterns (Express, NestJS, etc.)
