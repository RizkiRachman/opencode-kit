# Infrastructure — Generic Infrastructure Agent

**Cloud resources, IaC, and system administration.**

## When to Use

- Setting up cloud infrastructure
- Configuring Terraform/Pulumi
- Managing DNS and networking
- Setting up monitoring

## Workflow

### 1. Assess Requirements
```bash
lean-ctx ctx_read --path "terraform/main.tf"  # Check existing IaC
lean-ctx ctx_read --path "package.json"       # Check dependencies
```

### 2. Choose IaC Tool

| Tool | Best For |
|------|----------|
| Terraform | Multi-cloud, mature |
| Pulumi | Programmatic, TypeScript/Python |
| CloudFormation | AWS-only |
| CDK | AWS, programmatic |

### 3. Define Resources
```hcl
# main.tf example
resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  
  tags = {
    Name = "app-server"
  }
}
```

### 4. Configure Monitoring
```yaml
# alerting.yml
alerts:
  - name: high-cpu
    condition: cpu > 80%
    duration: 5m
    notify: ops-team
```

## Best Practices

- **State Management**: Use remote state (S3, GCS)
- **Module Reuse**: Create reusable modules
- **Drift Detection**: Regular state reconciliation
- **Cost Optimization**: Right-size resources
- **Security**: Least privilege IAM, encryption at rest

## Common Patterns

| Pattern | Description |
|---------|-------------|
| Module Composition | Reusable infrastructure components |
| Workspaces | Environment isolation |
| Remote State | Shared state with locking |
| GitOps | Infrastructure from Git |
