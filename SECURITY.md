# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 3.x     | :white_check_mark: |
| < 3.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it by opening an issue or emailing the maintainer directly.

For sensitive vulnerabilities, please do not open a public issue. Instead, contact the maintainer privately.

## Security Considerations

### OpenSSL 1.1.1w Fallback

This project permits OpenSSL 1.1.1w as a fallback dependency. This is intentional for compatibility with:

- Older Ruby versions that don't support OpenSSL 3.x
- Legacy gems with native extensions requiring OpenSSL 1.1
- Transitive dependencies not yet updated for OpenSSL 3.x

The default build uses the latest OpenSSL version. The fallback only activates when a dependency explicitly requires it.

### Nix Sandbox

All builds run in Nix's sandboxed environment:

- No network access during build/install phases
- Reproducible builds with pinned dependencies
- Fixed-output derivations with SHA256 verification for all fetched content

### Dependency Verification

- All gem sources are verified via SHA256 hashes in `gemset.nix`
- Bundler versions are pinned with precomputed hashes in `bundler-hashes.nix`
- The flake lockfile pins all Nix dependencies

### Docker Images

Generated Docker images follow security best practices:

- Minimal base images
- Non-root user execution where possible
- No unnecessary packages included

## Best Practices for Users

1. **Pin your dependencies**: Use `flake.lock` and `Gemfile.lock` for reproducible builds
2. **Review gemset.nix**: Verify gem sources before building
3. **Update regularly**: Keep dependencies current for security patches
4. **Use environment variables**: Never hardcode secrets in Nix files
