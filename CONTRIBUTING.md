# Contributing to Ruby Builder

Thank you for your interest in contributing! This project supports the entire Ruby ecosystem with Nix-based builds.

## Development Setup

1. Clone the repository
2. Ensure you have Nix with flakes enabled
3. Run `nix develop` to enter the development environment

## Testing

```bash
# Run all tests
./run-tests.sh

# Run specific test categories
./run-tests.sh basic           # Test basic build functionality
./run-tests.sh templates       # Test template validity
./run-tests.sh cross-platform  # Test cross-platform compatibility

# Run flake checks
nix flake check
```

## Architecture Overview

### Build Approaches

The project provides two build approaches:

- **Bundler Approach** (`with-bundler`): Traditional bundle exec, Darwin-compatible
- **Bundix Approach** (`with-bundix`): Pure Nix bundlerEnv, Linux-optimized

### Key Files

| File | Purpose |
|------|---------|
| `flake.nix` | Main flake definition and test infrastructure |
| `templates/universal/flake.nix` | User-facing template (single source of truth) |
| `imports/make-rails-build.nix` | Bundler-based build logic |
| `imports/make-rails-nix-build.nix` | BundlerEnv-based build logic |
| `bundler-hashes.nix` | Precomputed SHA256 hashes for bundler versions |
| `nixos-modules/rails-app.nix` | NixOS service module for deployment |

### Framework Detection

The universal template automatically detects frameworks from `Gemfile.lock`:

- Rails, Hanami, Sinatra, Rack, or plain Ruby
- Database support (PostgreSQL, MySQL, SQLite)
- Cache support (Redis, Memcached)
- Asset pipeline requirements

## Contribution Guidelines

### Code Style

- Follow existing Nix formatting conventions
- Keep functions focused and well-documented
- Test changes on both Darwin and Linux when possible

### Development Workflow

1. Test fixes in a local project first
2. Apply working changes to `templates/universal/flake.nix`
3. Ensure both bundler and bundix approaches work
4. Run the test suite before submitting

### Code Duplication Prevention

Development shells and package builds should share code wherever possible:

- Both approaches should use identical environment setups
- Extract common logic into shared functions
- When fixing one approach, apply similar fixes to the other

### Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Run `nix flake check` to verify
5. Submit a pull request with a clear description

## Areas Welcome for Contribution

- Additional framework detection patterns
- New gem-based dependency detection
- Platform-specific optimizations
- Documentation improvements
- Bug fixes and error handling

## Nix-Specific Notes

### Network Access Rules

Network operations must happen in the **fetch phase** using fixed-output derivations, never in build/install phases (they're sandboxed).

### SHA Mismatch Handling

The bundix approach includes automatic SHA fixing for common gems. For new gems:

1. Check if the gem needs platform-specific handling
2. Update the fix-gemset-sha logic if needed
3. Consider adding to the automatic fix list

## Questions?

Open an issue for questions, bug reports, or feature requests.
