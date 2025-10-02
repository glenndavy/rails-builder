# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Rails Builder is a Nix-based Ruby application builder that provides cross-platform compatibility for building Ruby applications. It supports Rails, Hanami, Sinatra, Rack applications, and plain Ruby projects. It offers two primary approaches:

1. **Traditional Bundler approach** (`with-bundler`) - Uses bundle exec, compatible with Darwin
2. **Pure Nix approach** (`with-bundix`) - Uses bundlerEnv, Linux-focused with direct gem access

The project provides Nix flake templates with automatic framework detection and handles the complexity of cross-platform Ruby deployment.

## Common Commands

### Testing
```bash
# Run all tests
./run-tests.sh

# Run specific test categories
./run-tests.sh basic           # Test basic build functionality
./run-tests.sh templates       # Test template validity  
./run-tests.sh cross-platform  # Test cross-platform compatibility
./run-tests.sh individual      # Run all tests individually
```

### Development
```bash
# Show flake version
nix run .#flakeVersion

# Initialize templates in a new project
nix flake init -t github:glenndavy/rails-builder#rails    # Rails-specific template
nix flake init -t github:glenndavy/rails-builder#ruby     # Generic Ruby (auto-detects framework)

# Development shells
nix develop .#with-bundler    # Darwin-compatible, uses bundle exec
nix develop .#with-bundix     # Linux-focused, direct gem access

# Package builds
nix build .#package-with-bundler   # Traditional bundler build
nix build .#package-with-bundix    # Pure Nix bundlerEnv build

# Docker images
nix build .#docker-with-bundler    # Docker with bundler
nix build .#docker-with-bundix     # Docker with bundlerEnv

# Check all tests
nix build .#checks.x86_64-linux.runAllTests
```

### Version Management
The version is statically set in `flake.nix` (`version = "2.1.0-static"`) but can be overridden with `--impure` flag for git-based versioning.

## Architecture

### Core Components

**Flake Structure (`flake.nix`)**:
- Main entry point defining inputs (nixpkgs, nixpkgs-ruby)
- Exports library functions for all supported systems
- Provides templates and test infrastructure
- Supports cross-platform builds (x86_64/aarch64 for both Linux and Darwin)

**Build Functions (`imports/`)**:
- `make-rails-build.nix` - Traditional bundler-based Rails builds
- `make-rails-nix-build.nix` - Pure Nix bundlerEnv builds  
- Helper scripts for database management, dependency generation

**Templates (`templates/`)**:
- `ruby/` - Generic Ruby template with automatic framework detection (Rails, Hanami, Sinatra, Rack, plain Ruby)
- `rails/` - Rails-specific template with both bundler and bundix approaches
- `build-rails/` - Legacy bundler-only template
- `build-rails-with-nix/` - Legacy bundlerEnv-only template

### Build Approaches

**Bundler Approach** (Darwin-compatible):
- Uses traditional `bundle exec` commands
- Works reliably on macOS with native extensions
- Builds gems during container runtime

**Bundix Approach** (Linux-optimized):
- Uses Nix's `bundlerEnv` for pure dependency management
- Direct gem access without bundle exec
- Pre-built gems in Nix store
- **Automatic SHA fixing** for common problematic gems (nokogiri, json, bootsnap, etc.)

### Cross-Platform Strategy

The codebase elegantly handles the Darwin bundlerEnv limitation by providing parallel implementations rather than trying to force compatibility. Users choose the appropriate approach for their platform.

### Testing Infrastructure

Comprehensive test suite in `flake.nix` checks:
- Basic build functionality across platforms
- Template validity and structure
- Cross-platform compatibility
- Integration testing with mock Rails apps

## Key Files

- `flake.nix` - Main flake definition and test infrastructure
- `run-tests.sh` - Test runner script with platform detection
- `imports/make-rails-build.nix` - Bundler-based build logic
- `imports/make-rails-nix-build.nix` - BundlerEnv-based build logic
- `bundler-hashes.nix` - Precomputed hashes for bundler versions
- `nixos-modules.nix` - NixOS service modules for deployment

## Development Notes

- The project uses nixpkgs-ruby overlay for comprehensive Ruby version support
- Build outputs include standalone packages, Docker images, and NixOS modules
- Debug output is extensively used throughout build phases for troubleshooting
- Universal build inputs are shared between both build approaches for consistency
- **Automatic SHA fixing**: The bundix approach now automatically fixes SHA mismatches for common problematic gems during build time, eliminating the need for manual `fix-gemset-sha` steps in most cases

## Framework Support

### Automatic Framework Detection
The `ruby` template automatically detects your Ruby application framework:

- **Rails**: Detected by `config/application.rb` and `rails` gem
- **Hanami**: Detected by `config/app.rb` and `hanami` gem  
- **Sinatra**: Detected by `config.ru` and `sinatra` gem
- **Rack**: Detected by `config.ru` (generic Rack app)
- **Ruby with Rake**: Detected by `Rakefile`
- **Plain Ruby**: Default fallback

### Framework-Specific Features
- **Asset compilation**: Automatic based on detected asset gems (sprockets, webpacker, vite, etc.)
- **Database support**: Only included if database gems are present in Gemfile.lock:
  - PostgreSQL support if `pg` gem detected
  - MySQL support if `mysql2` gem detected  
  - SQLite support if `sqlite3` gem detected
- **Cache support**: Only included if cache gems are present:
  - Redis support if `redis`, `redis-rails`, or `redis-store` gems detected
  - Memcached support if `memcached` or `dalli` gems detected
- **Build optimization**: Only includes dependencies needed for detected gems
- **Environment setup**: Framework and gem-appropriate environment variables

## SHA Mismatch Resolution

The templates now include automatic SHA fixing for bundix builds. If you encounter SHA mismatches:

1. **Automatic**: Most common gems (nokogiri, json, bootsnap, etc.) are fixed automatically during build
2. **Manual**: For other gems, use `nix run .#fix-gemset-sha` in your project
3. **Disable**: Set `autoFix = false` in bundlerEnv call if needed