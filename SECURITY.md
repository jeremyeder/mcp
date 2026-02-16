# Security Documentation

## Overview

This document outlines the security measures implemented in the MCP ACP server to ensure safe operation in production environments.

**Security Version:** 2.0.0
**Last Updated:** 2026-02-15

---

## Table of Contents

1. [Security Features](#security-features)
2. [Threat Model](#threat-model)
3. [Best Practices](#best-practices)
4. [Security Checklist](#security-checklist)
5. [Reporting Security Issues](#reporting-security-issues)

---

## Security Features

### 1. Input Validation and Sanitization

**Kubernetes Resource Name Validation**
- All resource names (sessions, projects) are validated against DNS-1123 subdomain format
- Pattern: `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
- Maximum length: 253 characters
- Prevents: Injection attacks via malformed names

**URL Validation**
- Server URLs must start with `https://` or `http://`
- Direct Kubernetes API URLs (port 6443) are rejected
- Prevents: Direct K8s API access bypassing the gateway

### 2. Gateway URL Enforcement

**Port 6443 Rejection**
- The `ClusterConfig` validator rejects any server URL containing `:6443`
- Users must connect through the public-api gateway, not directly to the Kubernetes API
- Example:
  ```python
  # Rejected — direct K8s API
  server: "https://api.cluster.example.com:6443"

  # Accepted — public-api gateway
  server: "https://public-api-ambient.apps.cluster.example.com"
  ```

### 3. HTTP Client Security

**Bearer Token Authentication**
- All API calls include `Authorization: Bearer <token>` header
- Tokens sourced from `clusters.yaml` or `ACP_TOKEN` environment variable
- Token resolution: config file → environment variable → error

**TLS**
- Server URLs must use `https://` (or `http://` for development)
- httpx client follows redirects securely

**Request Timeouts**
- Default HTTP timeout: 30 seconds
- Prevents hung connections from blocking operations

### 4. Bulk Operation Safety

**Item Limits**
- Maximum 3 items per bulk operation
- Prevents accidental mass deletion

**Confirmation Requirement**
- Destructive bulk operations require `confirm=true`
- Dry-run mode available for preview before execution

### 5. Data Protection

**Sensitive Data in Logs**
- Tokens, passwords, secrets filtered from logs
- Log sanitization in server.py:
  ```python
  safe_args = {k: v for k, v in arguments.items()
               if k not in ['token', 'password', 'secret']}
  ```

**Configuration Security**
- `clusters.yaml` contains Bearer tokens — must be secured with 0600 permissions
- Tokens should not be committed to version control

### 6. Error Handling

**Graceful Degradation**
- Client methods return error dicts instead of raising exceptions
- Prevents information leakage via stack traces
- Structured error responses for LLMs

**Exception Categories**
- `ValueError`: Input validation failures (logged as warnings)
- `TimeoutError`: HTTP request timeouts (logged as errors)
- `Exception`: Unexpected errors (logged with full stack trace)

---

## Threat Model

### Threats Mitigated

1. **Input Injection** ✅
   - Prevented via DNS-1123 validation on all resource names
   - No shell execution — all operations via HTTP REST

2. **Direct K8s API Access** ✅
   - Port 6443 URLs rejected at configuration validation
   - Forces traffic through the public-api gateway

3. **Resource Exhaustion** ✅
   - HTTP request timeouts (30 seconds)
   - Bulk operation limits (max 3 items)

4. **Information Disclosure** ✅
   - Sensitive data filtered from logs
   - Error messages sanitized

5. **Token Compromise** ⚠️
   - Mitigation: Secure clusters.yaml with 0600 permissions
   - Mitigation: Use short-lived tokens, rotate regularly
   - Mitigation: Use ACP_TOKEN env var instead of file storage where possible

6. **Man-in-the-Middle** ✅
   - Mitigation: TLS required for server URLs
   - Mitigation: httpx validates certificates by default

7. **Privilege Escalation** ✅
   - Limited to gateway RBAC permissions
   - No direct cluster access

### Residual Risks

1. **Compromised Bearer Token**
   - Mitigation: Short token lifetimes, token rotation
   - Monitor for unusual activity

2. **Gateway Vulnerabilities**
   - Mitigation: Keep gateway service updated
   - Rely on gateway's built-in security

3. **Dependency Vulnerabilities**
   - Mitigation: Regular dependency updates
   - Security scanning in CI/CD

---

## Best Practices

### For Deployment

1. **Configuration Security**
   - Ensure `~/.config/acp/` has 0700 permissions
   - Ensure `clusters.yaml` has 0600 permissions (it contains tokens)
   - Never commit `clusters.yaml` to version control

2. **Authentication**
   - Use Bearer token authentication
   - Rotate tokens regularly
   - Prefer `ACP_TOKEN` environment variable over file storage in CI/CD

3. **Logging**
   - Monitor logs for validation errors (potential attack attempts)
   - Set up alerts for repeated timeout errors
   - Review error logs regularly

4. **Updates**
   - Keep dependencies updated (mcp, httpx, pydantic, etc.)
   - Monitor security advisories for Python and dependencies
   - Test updates in staging before production

### For Development

1. **Adding New Tools**
   - Always validate inputs with `_validate_input()`
   - Implement dry-run mode for mutating operations
   - All API calls go through `_request()` method
   - Never log tokens or credentials

2. **Testing**
   - Test with malicious inputs
   - Test timeout scenarios
   - Test bulk operation limits

---

## Security Checklist

Before deploying to production:

- [ ] `clusters.yaml` has 0600 permissions (contains tokens)
- [ ] Config directory has 0700 permissions
- [ ] Logging configured and monitored
- [ ] All dependencies updated to latest secure versions
- [ ] Token rotation policy in place
- [ ] No tokens committed to version control
- [ ] Rate limiting configured (if exposing via HTTP)

---

## Reporting Security Issues

If you discover a security vulnerability, please:

1. **Do not** open a public GitHub issue
2. Email the maintainers directly
3. Provide detailed reproduction steps
4. Allow time for a fix before public disclosure

---

## Future Security Enhancements

1. **Rate Limiting** (if exposing via HTTP)
   - Per-client request limits
   - Token bucket algorithm

2. **Audit Logging**
   - Structured audit trail
   - Security event logging
   - Integration with SIEM

3. **Authentication Enhancements**
   - OAuth2/OIDC support
   - JWT token validation

4. **Network Security**
   - mTLS for MCP transport
   - Certificate pinning

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Python Security Best Practices](https://python.readthedocs.io/en/stable/library/security_warnings.html)

---

## Version History

**v2.0.0 (2026-02-15)** - Gateway architecture
- Replaced subprocess/oc CLI with httpx REST client
- Added gateway URL enforcement (port 6443 rejection)
- Bearer token authentication
- Simplified security model (no subprocess, no temp files)

**v1.0.0 (2026-01-29)** - Initial security hardening
- Input validation and sanitization
- Resource exhaustion protection
- Sensitive data filtering

All 8 MCP tools operate with defense-in-depth security controls.
