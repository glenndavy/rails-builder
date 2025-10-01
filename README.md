# Ruby Builder

A Nix-based Ruby application builder that provides cross-platform compatibility for building Ruby applications. Supports Rails, Hanami, Sinatra, Rack applications, and plain Ruby projects with automatic framework and dependency detection.

## 🚀 Quick Start

### For Any Ruby Application (Recommended)
```bash
# In your Ruby project directory
nix flake init -t github:glenndavy/rails-builder#ruby

# Start developing immediately
nix develop
```

### For Rails-Specific Projects
```bash
# In your Rails project directory  
nix flake init -t github:glenndavy/rails-builder#rails

# Choose your approach
nix develop .#with-bundler    # Traditional bundler (works on macOS)
nix develop .#with-bundix     # Pure Nix approach (Linux-optimized)
```

## 📋 Requirements

- Nix package manager with flakes enabled
- Your Ruby project with:
  - `Gemfile` and `Gemfile.lock`
  - `.ruby-version` file (or Ruby version specified in Gemfile)

## 🔧 What It Does

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

## 📚 Usage Examples

### Rails Application

```bash
# Your Rails app with PostgreSQL and Redis
cd my-rails-app
nix flake init -t github:glenndavy/rails-builder#ruby
nix develop

# What you get:
# ✅ Rails detected
# ✅ PostgreSQL support (pg gem found)
# ✅ Redis support (redis gem found)  
# ✅ Asset compilation (sprockets detected)
# ✅ Database management scripts
```

### Hanami Application

```bash
# Your Hanami app
cd my-hanami-app  
nix flake init -t github:glenndavy/rails-builder#ruby
nix develop

# What you get:
# ✅ Hanami detected
# ✅ Framework-specific commands
# ✅ Only dependencies your app uses
```

### Sinatra API

```bash
# Your Sinatra API with just PostgreSQL
cd my-api
nix flake init -t github:glenndavy/rails-builder#ruby
nix develop

# What you get:
# ✅ Sinatra/Rack detected
# ✅ PostgreSQL support only
# ❌ No Redis (not in Gemfile.lock)
# ❌ No asset compilation (not needed)
```

### Plain Ruby Project

```bash
# Your Ruby library or CLI tool
cd my-ruby-lib
nix flake init -t github:glenndavy/rails-builder#ruby  
nix develop

# What you get:
# ✅ Ruby environment
# ✅ Minimal dependencies
# ❌ No databases (not needed)
# ❌ No web server tools
```

## 🛠 Development Commands

### Available Shells

```bash
# Auto-detected shell (recommended)
nix develop

# Traditional bundler approach (macOS compatible)
nix develop .#with-bundler

# Pure Nix approach (Linux optimized, automatic SHA fixing)
nix develop .#with-bundix
```

### Inside the Shell

```bash
# Framework-specific commands shown based on detection
# For Rails:
rails server
rails console

# For Hanami:
hanami server
hanami console

# For Sinatra/Rack:
rackup
bundle exec ruby app.rb

# Universal commands:
bundle install
bundle exec <command>
```

### Database Management (if detected)

```bash
# Available only if database gems are present
manage-postgres     # Start/stop PostgreSQL
manage-redis        # Start/stop Redis

# Database will be auto-configured for your framework
```

## 📦 Building and Deployment

### Development Builds

```bash
# Build your application
nix build .#package-with-bundler   # Traditional approach
nix build .#package-with-bundix    # Pure Nix approach
```

### Docker Images

```bash
# Create production Docker images
nix build .#docker-with-bundler
nix build .#docker-with-bundix

# Load and run
docker load < result
docker run your-app:latest
```

## 🎯 Framework-Specific Features

### Rails Applications
- Asset precompilation (`rake assets:precompile`)
- Database migrations and seeds
- Rails-specific environment variables
- Binstubs and Rails commands

### Hanami Applications  
- Asset compilation (`hanami assets compile`)
- Hanami-specific commands and console
- Framework environment setup

### Sinatra/Rack Applications
- Automatic `rackup` configuration
- Minimal overhead
- Optional asset compilation if detected

### Plain Ruby Projects
- Clean Ruby environment
- Rake tasks if `Rakefile` present
- Gem building if gemspec detected

## 🔍 Inspection Commands

```bash
# See what was detected
nix run .#detectFramework

# Output example:
# Framework: rails
# Database gems detected:
#   PostgreSQL (pg): yes  
#   Redis: yes
# Has assets: yes (sprockets)
```

## 🛠 Advanced Configuration

### Bundix Approach (SHA Auto-fixing)

The bundix approach automatically fixes SHA mismatches for common gems:

```bash
# Generate gemset.nix
bundix

# Use with auto-fixing (default)
nix develop .#with-bundix

# Manual SHA fixing if needed
nix run .#fix-gemset-sha
```

### Custom Overrides

You can customize the generated `flake.nix`:

```nix
# Add custom gems or modify detection
frameworkInfo = detectFramework {src = ./.;} // {
  needsCustomService = true;  # Force include custom service
};
```

## 🏗 Build Approaches

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

## 🔧 Troubleshooting

### SHA Mismatch Errors
```bash
# Automatic fixing (included by default)
nix develop .#with-bundix

# Manual fixing
nix run .#fix-gemset-sha
```

### Missing Dependencies
The flake only includes dependencies for gems found in your `Gemfile.lock`. If you need additional services:

1. Add the gem to your `Gemfile`
2. Run `bundle install`  
3. Reinitialize: `nix develop`

### Platform Issues
- **macOS**: Use `with-bundler` for best compatibility
- **Linux**: Use `with-bundix` for optimal performance
- **Both**: The default shell auto-detects the best approach

## 🎯 Use Cases

### Development
- Instant Ruby environment setup
- All dependencies automatically included
- Framework-specific tooling ready
- Database services if needed

### CI/CD
- Reproducible builds across environments
- Minimal Docker images
- Framework-agnostic approach
- Automatic dependency detection

### Production Deployment  
- Self-contained applications
- Multiple deployment formats (Docker, NixOS, etc.)
- Optimal resource usage
- Security through isolation

## 🤝 Contributing

This project supports the entire Ruby ecosystem. Contributions welcome for:

- Additional framework detection
- New gem-based dependency detection
- Platform-specific optimizations
- Documentation improvements

## 📄 License

[Add your license here]

## 🔗 Related Projects

- [nixpkgs-ruby](https://github.com/bobvanderlinden/nixpkgs-ruby) - Ruby versions
- [bundix](https://github.com/nix-community/bundix) - Gemfile.lock to Nix conversion
- [Nix](https://nixos.org/) - The package manager