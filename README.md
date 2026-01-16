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
