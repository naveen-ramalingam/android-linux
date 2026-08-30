# Security Policy

## Supported versions

| Version | Supported |
|---------|:---------:|
| 1.x     | ✅        |

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Report privately so we can coordinate a fix before disclosure:

- Use GitHub's **private vulnerability reporting** if enabled on this repository, or
- Email the maintainers (add a contact here) with a detailed description and, if
  possible, a reproduction.

We aim to acknowledge reports within 48 hours and provide a fix or mitigation as quickly
as practical.

## Scope

AndroidLinux is designed to never modify Android itself. Vulnerabilities that could lead
to flashing, unlocking, system modification, or data loss are treated as high severity.

## Safe usage

- Only download rootfs archives from the official sources configured in `lib/*.sh`.
- Verify checksums; AndroidLinux does this automatically when sources publish them.
- Do not expose SSH or VNC to the public internet.
