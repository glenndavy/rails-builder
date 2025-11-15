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

## Critical Development Workflow

**IMPORTANT**: When debugging/fixing issues in a user's project, any working changes MUST be immediately propagated back to the rails-builder template source code. Common workflow:

1. Test fixes in user's local `flake.nix`
2. **IMMEDIATELY** apply working changes to `/templates/universal/flake.nix` in rails-builder
3. Update this CLAUDE.md with any new patterns or fixes discovered
4. Test template changes work from fresh init

This prevents losing working solutions that are only fixed locally.

## Code Duplication Prevention

**CRITICAL**: Development shells and package builds should share the same code wherever possible:

- Both bundler and bundix approaches should use identical environment setups
- Shell and package builds within each approach should share gem configurations
- Extract common logic into shared functions to prevent drift between dev/build environments
- When fixing one approach (shell or package), immediately apply similar fixes to the other
- Use consistent parameter passing and error handling across all build paths

This prevents inconsistencies where shells work but packages fail, or vice versa.

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

## Critical Architecture Decisions & Lessons Learned

### Bundler Derivation Architecture
**CRITICAL RULE**: Never do network operations in Nix build/install phases - they are sandboxed and will fail.

#### ❌ BROKEN PATTERN (What we fixed):
```nix
bundlerPackage = pkgs.stdenv.mkDerivation {
  installPhase = ''
    # FAILS: Network access blocked in sandboxed build environment
    ${rubyPackage}/bin/gem install bundler --version ${bundlerVersion}
  '';
};
```

#### ✅ CORRECT PATTERN:
```nix
# Use established nixpkgs patterns that handle network access properly
bundlerPackage = pkgs.bundler.override {
  ruby = rubyPackage;
};
```

**Key Insight**: Network access in Nix happens during the **fetch phase** using fixed-output derivations (FODs) with known SHA256 hashes. The build/install phases are sandboxed and cannot access networks.

### Bundix vs BundlerEnv Modes

#### Bootstrap Mode (Bundix)
- **Purpose**: Generate gemset.nix from Gemfile.lock for new projects
- **Tools Available**: bundix, Ruby, bundler, build dependencies
- **Gem Access**: None directly (must use bundle exec or generate gemset.nix first)
- **Use Case**: Initial project setup, gem updates, SHA mismatch fixes

#### Production Mode (BundlerEnv)
- **Purpose**: Direct gem access without bundle exec using pre-built gems
- **Tools Available**: All gems directly accessible via Nix store paths
- **Gem Access**: Direct (e.g., `ruby -e "require 'rails'"` works)
- **Use Case**: Running applications, development with fast gem access

### Platform-Specific Gem Variants
The fix-gemset-sha script handles multi-platform gems automatically:
- `nokogiri-1.18.8-x86_64-linux-gnu.gem`
- `nokogiri-1.18.8-aarch64-linux-gnu.gem`
- `nokogiri-1.18.8-arm64-darwin.gem`
- etc.

This enables proper cross-platform builds without manual SHA management.

### Network Dependency Resolution Rules

1. **Fetch Phase**: Network allowed for fixed-output derivations (gems, source code)
2. **Build Phase**: Network blocked - all dependencies must be pre-fetched
3. **Install Phase**: Network blocked - only file operations allowed
4. **Runtime**: No special restrictions

**Lesson**: Previous "working" bundler derivations likely succeeded due to cache hits, not proper architecture. Network calls in build phases are fundamentally unsound in Nix.

### Infrastructure Rules for Bundler Management

**CRITICAL: Use Existing Infrastructure, Don't Reinvent**

1. **bundler-hashes.nix**: Contains pre-computed SHA256 hashes for all bundler versions
   - Never hardcode bundler hashes in flake.nix
   - Always reference: `bundlerHashes.${bundlerVersion}.sha256`
   - Update with existing scripts when new versions needed

2. **#bundlerVersion app**: Extracts bundler version from Gemfile.lock
   - Use this to detect required version dynamically
   - Never assume or hardcode bundler versions

3. **Bundler Derivation Pattern**:
   ```nix
   bundlerHashes = import ./bundler-hashes.nix;
   bundlerPackage = let
     bundlerInfo = bundlerHashes.${bundlerVersion} or (throw "Bundler version ${bundlerVersion} not found");
   in pkgs.buildRubyGem rec {
     ruby = rubyPackage;
     source.sha256 = bundlerInfo.sha256;
     # ... rest of config
   };
   ```

4. **Path Configuration**: Include both derivation gems and local project gems
   - `GEM_PATH="${bundlerPackage}/lib/ruby/gems/${rubyMajorMinor}.0:$PROJECT/vendor/bundle/ruby/${rubyMajorMinor}.0"`
   - `RUBYLIB` must include bundler derivation gem paths

**Never**: Hardcode versions, bypass bundler-hashes.nix, or do manual gem installation in build phases.

## SHA Mismatch Resolution

The templates now include automatic SHA fixing for bundix builds. If you encounter SHA mismatches:

1. **Automatic**: Most common gems (nokogiri, json, bootsnap, etc.) are fixed automatically during build
2. **Manual**: For other gems, use `nix run .#fix-gemset-sha` in your project
3. **Disable**: Set `autoFix = false` in bundlerEnv call if needed

## NixOS Module Specifications

Rails-builder will provide a NixOS module for systemd service deployment with the following features:

### Core Service Configuration
1. **Systemd service**: Automatic service definition for the application
2. **Service dependencies**: Configure services that must start before this service
3. **Service dependents**: Configure services that depend on this service (systemd wants)
4. **Service description**: Configurable description for the systemd service

### Command Execution (either/or)
- **Option A**: Direct command specification via `command` variable
- **Option B**: Procfile-based command extraction:
  - `procfile_role`: Role name to extract from Procfile (e.g., "web", "worker")
  - `procfile_filename`: Path to Procfile (defaults to "Procfile")

### Service Lifecycle Management
5. **Stop command**: Custom command for service termination (`stop_command`)
6. **Restart command**: Custom command for service restart (`restart_command`)
7. **Service ordering**: Additional systemd services to start after (`service_after`)

### Environment Management
8. **Environment setup command**: Command to populate shell with environment variables
9. **Environment variable overrides**: List of environment variables that take precedence over setup command

### Design Decisions (Clarified)

**Service Dependencies**: Use both `systemd.services.<name>.after` (ordering) and `systemd.services.<name>.requires` (hard dependencies) for comprehensive dependency management.

**Procfile Integration**: Manual specification initially - users specify `procfile_role` and `procfile_filename` explicitly. Auto-detection can be added later as enhancement.

**Environment Management**: Environment setup command executes at service start to populate environment variables (e.g., from AWS Parameter Store). The service environment is then populated with these variables plus any configured overrides.

**Service Architecture**: One service per application role. Multiple roles (web, worker, cron) are separate service configurations, each with their own module instance.

**Working Directory**: Run from immutable Nix store path (e.g., `/nix/store/.../app`) with mutable directories (tmp, logs) symlinked to `/var/lib/<service>/tmp`, `/var/log/<service>/`, etc.

### Implementation Architecture

```nix
# Example module usage
services.rails-app = {
  web = {
    enable = true;
    procfile_role = "web";
    procfile_filename = "/nix/store/.../app/Procfile";
    environment_command = "aws ssm get-parameters-by-path --path /myapp/prod";
    environment_overrides = {
      RAILS_ENV = "production";
      PORT = "3000";
    };
    service_after = [ "postgresql.service" "redis.service" ];
    service_description = "MyApp Web Server";
  };
  worker = {
    enable = true;
    procfile_role = "worker";
    # ... similar configuration for background jobs
  };
};
```

### Mutable Directory Strategy
- **Working Directory**: `/nix/store/.../app` (immutable)
- **Tmp Directory**: Symlink `./tmp` → `/var/lib/<service>/tmp`
- **Log Directory**: Symlink `./log` → `/var/log/<service>/`
- **Uploads/Storage**: Symlink `./storage` → `/var/lib/<service>/storage`

### Environment Variable Flow
1. Service starts
2. Environment command executes (e.g., fetch from Parameter Store)
3. Environment overrides apply on top
4. Application launches with combined environment

## NixOS Module Usage

Rails-builder provides a universal NixOS module that works with **any Ruby framework**. Choose the module name that matches your framework for clarity:

- `rails-builder.nixosModules.rails-app` - For Rails applications
- `rails-builder.nixosModules.hanami-app` - For Hanami applications
- `rails-builder.nixosModules.sinatra-app` - For Sinatra applications
- `rails-builder.nixosModules.rack-app` - For Rack applications
- `rails-builder.nixosModules.ruby-app` - Generic (works with all)

All aliases point to the same universal module - use whichever feels most natural!

### Rails Example

```nix
{
  inputs.rails-builder.url = "github:glenndavy/rails-builder";

  outputs = { nixpkgs, rails-builder, ... }: {
    nixosConfigurations.myserver = nixpkgs.lib.nixosSystem {
      modules = [
        rails-builder.nixosModules.rails-app  # Rails-specific alias
        {
          services.rails-app.web = {
            enable = true;
            package = myRailsAppPackage;
            command = "bundle exec rails server -p 3000";

            environment_command = "aws ssm get-parameters-by-path --path /myapp/prod";
            environment_overrides = {
              RAILS_ENV = "production";
              PORT = "3000";
            };

            service_after = [ "postgresql.service" ];
            service_requires = [ "postgresql.service" ];
          };
        }
      ];
    };
  };
}
```

### Hanami Example

```nix
{
  modules = [
    rails-builder.nixosModules.hanami-app  # Hanami-specific alias
    {
      services.rails-app.web = {
        enable = true;
        package = myHanamiAppPackage;
        command = "bundle exec hanami server";

        environment_overrides = {
          HANAMI_ENV = "production";
          DATABASE_URL = "postgres://localhost/myapp_production";
        };
      };
    }
  ];
}
```

### Sinatra Example

```nix
{
  modules = [
    rails-builder.nixosModules.sinatra-app  # Sinatra-specific alias
    {
      services.rails-app.api = {
        enable = true;
        package = mySinatraAppPackage;
        command = "bundle exec rackup -p 4567";

        environment_overrides = {
          RACK_ENV = "production";
        };
      };
    }
  ];
}
```

### Multi-Role Deployment

```nix
services.rails-app = {
  web = {
    enable = true;
    package = myRailsApp;
    procfile_role = "web";
    procfile_filename = "${myRailsApp}/app/Procfile";
    environment_overrides.PORT = "3000";
  };

  worker = {
    enable = true;
    package = myRailsApp;
    procfile_role = "worker";
    procfile_filename = "${myRailsApp}/app/Procfile";
    environment_overrides.WORKER_THREADS = "10";
  };

  scheduler = {
    enable = true;
    package = myRailsApp;
    command = "bundle exec clockwork config/schedule.rb";
  };
};
```

### Key Features

- **Secure Environment Handling**: Environment variables fetched at runtime, never written to disk
- **Procfile Support**: Automatically parse Procfile entries for different roles
- **Mutable Directory Management**: Automatically links tmp, log, storage directories
- **Service Dependencies**: Full systemd dependency management (after, requires, wantedBy)
- **Multiple Instances**: Deploy multiple roles (web, worker, scheduler) from same app
- **Security Hardening**: Runs with restricted systemd security settings

### Available Options

See `nixos-modules/rails-app.nix` for full option documentation. Key options:

- `package`: Rails application derivation
- `command` or `procfile_role`/`procfile_filename`: Command specification
- `environment_command`: Script to fetch environment variables
- `environment_overrides`: Static environment variables
- `service_*`: Systemd service configuration
- `mutable_dirs`: Custom mutable directory mappings
- `user`/`group`: Service user configuration