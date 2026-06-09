# Ruby Builder

A Nix-based Ruby application builder that provides cross-platform compatibility for building Ruby applications. Supports Rails, Hanami, Sinatra, Rack applications, and plain Ruby projects with automatic framework and dependency detection.

## Quick Start

```bash
# In your Ruby project directory
nix flake init -t github:glenndavy/rails-builder#universal

# Start developing
nix develop
```

### Get Fresh Templates

```bash
# Bypass Nix caching for latest template
nix flake init -t github:glenndavy/rails-builder#universal --option tarball-ttl 0

# Or use versioned releases
nix flake init -t github:glenndavy/rails-builder/v3.2.0#universal
```

## Requirements

- Nix package manager with flakes enabled
- Your Ruby project with:
  - `Gemfile` and `Gemfile.lock`
  - `.ruby-version` file (or Ruby version specified in Gemfile)

## What It Does

### Automatic Detection

Ruby Builder automatically detects your application setup:

- **Framework**: Rails, Hanami, Sinatra, Rack, or plain Ruby
- **Databases**: PostgreSQL (`pg`), MySQL (`mysql2`), SQLite (`sqlite3`)
- **Cache Stores**: Redis (`redis*`), Memcached (`dalli`)
- **Asset Pipeline**: Sprockets, Webpacker, Vite, ESBuild, etc.
- **Ruby Version**: From `.ruby-version` or `Gemfile`

### Smart Dependencies

Only includes what your app actually uses:
- Database libraries only if database gems are present
- Redis/Memcached only if cache gems are detected
- Node.js only if assets need compilation
- Framework-specific tools and commands

## Development Shells

### Available Shells

```bash
# Auto-detected shell (recommended)
nix develop

# Traditional bundler approach (macOS compatible)
nix develop .#with-bundler

# Pure Nix approach (Linux optimized, requires gemset.nix)
nix develop .#with-bundix
```

### Enabling Bundix Support

The bundix approach requires a `gemset.nix` file:

```bash
# Generate gemset.nix from your Gemfile.lock
nix run .#generate-dependencies

# Now bundix shells and packages become available
nix develop .#with-bundix
```

### Recommended bundle config for Nix builds

For builds that go through rails-builder (especially the `with-bundix` path),
configure bundler **before** running `bundle install` / `bundle cache` so the
right gem variants get vendored:

```bash
# In your app root
bundle config set --local force_ruby_platform true
bundle config set --local path 'vendor/bundle'
bundle config set --local frozen true
bundle config set --local without 'development:test'   # production builds

bundle install
bundle cache --all                                      # populates vendor/cache/
git add vendor/cache vendor/bundle .bundle/config       # see flake-purity note below
```

Why each setting matters:

| setting | effect | why for Nix |
|---|---|---|
| `force_ruby_platform true` | Picks the source `.gem` (no platform suffix) over precompiled binaries | Nix compiles native extensions against its own libpq/libffi/libssl. Precompiled `*-x86_64-linux-gnu.gem` archives link against the publisher's libs, which won't match the Nix store. |
| `path vendor/bundle` | Installs gems under the project tree | Keeps the install local and inspectable. `bundlerEnv` uses its own location at build time, but matching layouts simplifies hybrid `bundle exec` workflows. |
| `frozen true` | Refuses to mutate `Gemfile.lock` during install | Reproducibility — the lockfile is the source of truth that `generate-dependencies` reads. |
| `without development:test` | Skips dev/test groups | Smaller production closure; faster Nix builds. Drop for full dev shells. |
| `bundle cache --all` | Copies `.gem` archives into `vendor/cache/` | `generate-dependencies` source-rewrites gemset entries to point at these local files — making the build hermetic from rubygems.org and pinning exact bytes. |

### Flake-purity note

When `nix develop` or `nix build` evaluates the flake from a git working
tree, Nix only sees **git-tracked** files. Anything in `vendor/cache/` or
`vendor/bundle/` that isn't staged or committed is invisible — including
the `.gem` archives that `customBundlerEnv` reads via `builtins.path`.

The fix is `git add vendor/cache/` (you don't have to commit — the index
is enough). If your repo has these directories in `.gitignore`, remove the
rule or use `git add -f`. For deploy-targeted Rails apps these are part
of the source of truth and worth versioning; if you'd rather not track
them, `nix develop --impure .` is an escape hatch but breaks reproducibility.

### Picking which variants to vendor

`bundle cache --all-platforms` is tempting but bites — it tries to fetch
every platform variant, and any single missing one (e.g. `bcrypt_pbkdf-1.1.2-arm64-darwin`,
which predates Apple Silicon) aborts the whole package step. For Nix builds
you only need the source variants (because `force_ruby_platform true` makes
bundler prefer them and Nix compiles natively anyway). Stick with the plain
`bundle cache`.

If a particular gem only ships precompiled binaries (no source variant on
rubygems), the `generate-dependencies` fallback will pick the matching
platform `.gem` from `vendor/cache/` instead. Add the deploy-target
platforms to `Gemfile.lock` if you need them resolved:

```bash
bundle lock --add-platform x86_64-linux
bundle lock --add-platform aarch64-linux
```

(Skip darwin platforms unless you're also deploying onto a Mac.)

## Database Services

Rails Builder includes PostgreSQL and Redis management for local development.

### PostgreSQL

```bash
manage-postgres help              # Show connection info
manage-postgres start             # Start server (port 5432)
manage-postgres start --port 5433 # Custom port
manage-postgres stop              # Stop server
```

**Connection Info:**
- Database: `rails_build`
- User: Your Unix username (no password)
- Host: Unix socket in `./tmp/`
- DATABASE_URL: `postgresql://username@localhost:5432/rails_build?host=/path/to/project/tmp`

### Redis

```bash
manage-redis help              # Show connection info
manage-redis start             # Start server (port 6379)
manage-redis start --port 6380 # Custom port
manage-redis stop              # Stop server
```

**Connection Info:**
- Host: `localhost`
- Port: `6379` (default)
- REDIS_URL: `redis://localhost:6379/0`

### Multiple Environments

Run multiple database instances with custom ports:

```bash
# Terminal 1: Development
manage-postgres start             # Port 5432
manage-redis start                # Port 6379
rails s                           # Port 3000

# Terminal 2: Test environment
manage-postgres start --port 5433
manage-redis start --port 6380
export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
export REDIS_URL="redis://localhost:6380/0"
rails s -p 3001
```

## Building and Deployment

### Application Packages

```bash
nix build .#package-with-bundler   # Traditional bundler build
nix build .#package-with-bundix    # Pure Nix build (requires gemset.nix)
```

### Docker Images

```bash
nix build .#docker-with-bundler    # Docker with bundler
nix build .#docker-with-bundix     # Docker with bundlerEnv

# Load and run
docker load < result
docker run -p 3000:3000 your-app:latest
```

## Bundix Workflow

For pure Nix gem management:

```bash
# 1. Generate gemset.nix
bundix

# 2. If SHA mismatches occur, fix automatically
nix run .#fix-gemset-sha

# 3. Use bundix environment
nix develop .#with-bundix
```

Benefits:
- Reproducible builds with exact gem versions
- No bundler needed at runtime
- Better Nix caching
- Native dependencies handled by Nix

## Template Aliases

All templates point to the same universal template:

| Template | Description |
|----------|-------------|
| `universal` | Universal Ruby template with smart detection |
| `rails` | Rails application template |
| `hanami` | Hanami application template |
| `sinatra` | Sinatra application template |
| `rack` | Rack application template |
| `ruby` | Generic Ruby template |

## Inspection Commands

```bash
nix run .#detectFramework      # Show detected framework and dependencies
nix run .#detectRubyVersion    # Show Ruby version
nix run .#detectBundlerVersion # Show Bundler version
nix run .#flakeVersion         # Show flake version
```

## Build Approaches

### Traditional Bundler (`with-bundler`)
- Uses `bundle exec` for all commands
- Compatible with macOS native extensions
- Builds gems during container runtime
- Familiar workflow for Ruby developers

### Pure Nix (`with-bundix`)
- Uses Nix's `bundlerEnv` for dependency management
- Direct gem access without `bundle exec`
- Automatic SHA fixing for common problematic gems
- Better caching and reproducibility
- Linux-optimized

## Troubleshooting

### SHA Mismatch Errors
```bash
nix run .#fix-gemset-sha
```

### Missing Dependencies
The flake only includes dependencies for gems in `Gemfile.lock`. Add gems and reinstall:
```bash
bundle install
nix develop  # Re-enter to pick up new dependencies
```

### Platform Issues
- **macOS**: Use `with-bundler` for best compatibility
- **Linux**: Use `with-bundix` for optimal performance
- **Both**: The default shell auto-detects the best approach

### Port Conflicts
```bash
lsof -i :5432  # Check PostgreSQL
lsof -i :6379  # Check Redis

# Use custom ports
manage-postgres start --port 5433
manage-redis start --port 6380
```

## NixOS Module

Deploy your Ruby application as a systemd service on NixOS:

```nix
{
  inputs.rails-builder.url = "github:glenndavy/rails-builder";

  outputs = { nixpkgs, rails-builder, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      modules = [
        rails-builder.nixosModules.rails-app
        {
          services.rails-app.web = {
            enable = true;
            package = myRailsApp;
            command = "bundle exec rails server -p 3000";
            environment_overrides.RAILS_ENV = "production";
            service_after = [ "postgresql.service" ];
          };
        }
      ];
    };
  };
}
```

**📖 [Complete NixOS Module Documentation](NIXOS-MODULE.md)** - Full guide with examples, configuration options, deployment workflows, and troubleshooting.

Features:
- **Automatic systemd service creation** with proper dependency management
- **Multi-role support** - Run web, worker, and scheduler processes
- **Procfile integration** - Extract commands from your Procfile
- **Secure environment management** - Fetch secrets from AWS Parameter Store
- **Mutable directory handling** - Automatic setup of tmp, log, and storage
- **Framework agnostic** - Works with Rails, Hanami, Sinatra, Rack, or any Ruby app

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## Security

See [SECURITY.md](SECURITY.md) for security policy and OpenSSL compatibility notes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby) - Ruby versions for Nix
- [bundix](https://github.com/nix-community/bundix) - Gemfile.lock to Nix conversion
- [Nix](https://nixos.org/) - The package manager
