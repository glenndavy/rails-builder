# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ruby Builder is a Nix-based Ruby application builder providing cross-platform compatibility for building Ruby applications. Supports Rails, Hanami, Sinatra, Rack applications, and plain Ruby projects with two primary approaches:

1. **Traditional Bundler approach** (`with-bundler`) - Uses bundle exec, compatible with Darwin
2. **Pure Nix approach** (`with-bundix`) - Uses bundlerEnv, Linux-focused with direct gem access

## Common Commands

### Testing
```bash
./run-tests.sh              # Run all tests
./run-tests.sh basic        # Test basic build functionality
./run-tests.sh templates    # Test template validity
nix flake check             # Run Nix checks
```

### Development
```bash
nix run .#flakeVersion                           # Show flake version
nix develop .#with-bundler                       # Darwin-compatible shell
nix develop .#with-bundix                        # Linux-focused shell
nix build .#package-with-bundler                 # Bundler build
nix build .#docker-with-bundler                  # Docker image
```

## Architecture

### Key Files
- `flake.nix` - Main flake definition and test infrastructure
- `templates/universal/flake.nix` - User-facing template (single source of truth)
- `imports/make-rails-build.nix` - Bundler-based build logic
- `imports/make-rails-nix-build.nix` - BundlerEnv-based build logic
- `bundler-hashes.nix` - Precomputed SHA256 hashes for bundler versions
- `nixos-modules/rails-app.nix` - NixOS service module

### Framework Detection
Automatic detection from `Gemfile.lock`:
- **Rails**: `config/application.rb` + `rails` gem
- **Hanami**: `config/app.rb` + `hanami` gem
- **Sinatra**: `config.ru` + `sinatra` gem
- **Rack**: `config.ru` (generic)
- **Plain Ruby**: Default fallback

### Database/Cache Detection
- PostgreSQL if `pg` gem detected
- MySQL if `mysql2` gem detected
- SQLite if `sqlite3` gem detected
- Redis if `redis*` gems detected
- Memcached if `dalli` gem detected

## Critical Rules

### Network Access in Nix
**Never do network operations in build/install phases** - they are sandboxed.

```nix
# WRONG - fails in sandbox
installPhase = ''
  gem install bundler
'';

# RIGHT - use fetch phase with known hashes
bundlerPackage = pkgs.buildRubyGem {
  source.sha256 = hashInfo.sha256;
  # ...
};
```

### Bundler Management
Use `bundler-hashes.nix` for reproducible bundler builds:
```nix
bundlerHashes = import ./bundler-hashes.nix;
bundlerPackage = let
  hashInfo = bundlerHashes.${bundlerVersion} or null;
in if hashInfo != null
   then pkgs.buildRubyGem { ... }
   else pkgs.bundler.override { ruby = rubyPackage; };
```

### Template Updates
When fixing issues in a user's project:
1. Test fixes in user's local `flake.nix`
2. Apply working changes to `templates/universal/flake.nix`
3. Test template changes work from fresh init

### Code Sharing
Development shells and package builds should share code:
- Both bundler/bundix approaches use identical environment setups
- When fixing one approach, apply similar fixes to the other
- Extract common logic into shared functions

## NixOS Module

Universal module for systemd service deployment supporting all Ruby frameworks:

```nix
services.rails-app.web = {
  enable = true;
  package = myRailsApp;
  command = "bundle exec rails server -p 3000";
  environment_overrides = {
    RAILS_ENV = "production";
  };
  service_after = [ "postgresql.service" ];
};
```

Module aliases for discoverability:
- `rails-builder.nixosModules.rails-app`
- `rails-builder.nixosModules.hanami-app`
- `rails-builder.nixosModules.sinatra-app`
- `rails-builder.nixosModules.rack-app`
- `rails-builder.nixosModules.ruby-app`

See `nixos-modules/rails-app.nix` for full options including:
- `procfile_role`/`procfile_filename` for Procfile parsing
- `environment_command` for runtime secrets fetching
- `mutable_dirs` for tmp/log/storage symlinks

## SHA Mismatch Resolution

Templates include automatic SHA fixing for common gems. For manual fixes:
```bash
nix run .#fix-gemset-sha
```

## OpenSSL Compatibility

OpenSSL 1.1.1w is permitted as fallback for:
- Older Ruby versions
- Legacy gems with native extensions
- Transitive dependencies requiring OpenSSL 1.1

The `opensslVersion` variable controls which version is used by default.
