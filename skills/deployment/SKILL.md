# Deployment — Generic Deployment Agent

**Application deployment and environment management.**

## When to Use

- Deploying applications to servers
- Configuring Docker containers
- Setting up Kubernetes
- Managing environment variables

## Workflow

### 1. Assess Application
```bash
lean-ctx ctx_read --path "package.json"  # Check scripts
lean-ctx ctx_read --path "Dockerfile"    # Check containerization
lean-ctx ctx_read --path "docker-compose.yml"
```

### 2. Choose Deployment Target

| Target | Best For |
|--------|----------|
| Vercel/Netlify | Frontend, JAMstack |
| AWS/GCP/Azure | Full-stack, enterprise |
| Railway/Render | Simple full-stack |
| Self-hosted | Full control |

### 3. Configure Deployment
```dockerfile
# Dockerfile example
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

### 4. Set Environment Variables
```bash
# .env.example
DATABASE_URL=postgresql://...
API_KEY=your-api-key
NODE_ENV=production
```

## Best Practices

- **Infrastructure as Code**: Version control all configs
- **Immutable Deployments**: Never modify running instances
- **Health Checks**: Always include liveness/readiness probes
- **Rollback Plan**: Know how to revert quickly
- **Secrets Management**: Use platform secrets, not .env files

## Common Patterns

| Pattern | Description |
|---------|-------------|
| Blue-Green | Two identical environments, swap traffic |
| Canary | Gradual rollout to subset of users |
| Rolling | Update instances one at a time |
| Serverless | Functions on-demand |
