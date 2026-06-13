# Security Audit — Generic Security Reviewer

**Vulnerability assessment and security best practices.**

## When to Use

- Reviewing code for security issues
- Auditing authentication/authorization
- Checking for common vulnerabilities
- Validating security configurations

## Workflow

### 1. Understand the Attack Surface
```bash
lean-ctx ctx_search --pattern "password|secret|token|key" --ext ".ts,.js,.py"
lean-ctx ctx_search --pattern "eval|exec|system|child_process"
```

### 2. Check OWASP Top 10

| # | Vulnerability | What to Look For |
|---|---------------|------------------|
| A01 | Broken Access Control | Missing auth checks, IDOR |
| A02 | Cryptographic Failures | Weak algorithms, hardcoded secrets |
| A03 | Injection | SQL, NoSQL, OS command injection |
| A04 | Insecure Design | Missing threat modeling |
| A05 | Security Misconfiguration | Default creds, verbose errors |
| A06 | Vulnerable Components | Outdated dependencies |
| A07 | Auth Failures | Weak passwords, no MFA |
| A08 | Data Integrity Failures | Unsigned updates, insecure deserialization |
| A09 | Logging Failures | No audit trail |
| A10 | SSRF | Unvalidated URLs |

### 3. Review Code
- Input validation and sanitization
- Output encoding
- Parameterized queries
- Proper error handling
- Secure session management

### 4. Generate Report
Document findings with:
- Severity (Critical/High/Medium/Low)
- Location (file:line)
- Description
- Remediation

## Best Practices

- **Defense in Depth**: Multiple layers of security
- **Least Privilege**: Minimal required permissions
- **Secure Defaults**: Safe out-of-the-box
- **Input Validation**: Never trust user input
- **Secrets Management**: Use env vars, not hardcoded values
