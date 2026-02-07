# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in A2AClient, please report it responsibly.

### How to Report

1. **Do NOT** create a public GitHub issue for security vulnerabilities
2. Use [GitHub Security Advisories](https://github.com/tolgaki/a2a-client-swift/security/advisories/new) to report vulnerabilities privately
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- Acknowledgment within 48 hours
- Regular updates on progress
- Credit in release notes (unless you prefer anonymity)

### Security Best Practices

When using A2AClient:

- Store credentials securely (use Keychain on Apple platforms)
- Never log or serialize authentication providers
- Use HTTPS for all agent communications
- Validate agent cards from untrusted sources
- Keep the library updated to the latest version

## Security Features

A2AClient includes several security features:

- **Input Validation**: Part content and AgentCard interfaces are validated during decoding
- **Path Injection Protection**: Task IDs and config IDs are sanitized before use in URLs
- **Credential Documentation**: Authentication providers include security warnings about credential handling
