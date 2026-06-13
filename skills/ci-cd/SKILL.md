# CI/CD — Generic DevOps Agent

**Continuous integration, deployment, and automation.**

## When to Use

- Setting up build pipelines
- Configuring test automation
- Deploying applications
- Automating workflows

## Workflow

### 1. Assess Current State
```bash
lean-ctx ctx_read --path "package.json"  # Check scripts
lean-ctx ctx_tree --depth 2              # See structure
```

### 2. Choose Platform
| Platform | Best For |
|----------|----------|
| GitHub Actions | GitHub repos, free tier |
| GitLab CI | GitLab repos, built-in |
| CircleCI | Complex pipelines |
| Jenkins | Self-hosted, full control |

### 3. Configure Pipeline
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm test
```

### 4. Add Deployment
- Use environment-specific secrets
- Implement rollback strategies
- Add health checks

## Best Practices

- **Fast Feedback**: Run tests on every push
- **Parallel Jobs**: Split test suites for speed
- **Caching**: Cache dependencies between runs
- **Security**: Scan for vulnerabilities
- **Rollback**: Always have a way to revert

## Common Patterns

| Pattern | Description |
|---------|-------------|
| Trunk-Based | Short-lived branches, frequent merges |
| GitFlow | Develop/main branches, releases |
| Feature Flags | Deploy dark, enable gradually |
| Blue-Green | Two identical environments |
