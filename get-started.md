# Rails Builder - Getting Started Guide

Rails Builder is a Nix-based Ruby application builder that provides cross-platform compatibility for building Ruby applications. It supports Rails, Hanami, Sinatra, Rack applications, and plain Ruby projects.

## Quick Start

```bash
# 1. Create project directory
mkdir my-rails-app && cd my-rails-app

# 2. Initialize with Rails Builder
nix flake init -t github:glenndavy/rails-builder#rails

# 3. Enter development shell
nix develop .#with-bundler

# 4. Start database and develop!
manage-postgres start
rails s
```

## Template Options

Rails Builder provides two templates to match your needs:

### 🚀 `#rails` - Rails-Specific Template
**Best for:** Dedicated Rails projects
**Includes:** All Rails tools and services (PostgreSQL, Redis, Node.js, etc.)

```bash
nix flake init -t github:glenndavy/rails-builder#rails
```

### 🎯 `#ruby` - Smart Auto-Detection Template
**Best for:** Any Ruby framework or mixed projects
**Includes:** Only the dependencies your project actually needs
**Detects:** Rails, Hanami, Sinatra, Rack, plain Ruby

```bash
nix flake init -t github:glenndavy/rails-builder#ruby
```

## New Application Setup

### Option 1: New Rails Application

```bash
# 1. Create and enter project directory
mkdir my-rails-app
cd my-rails-app

# 2. Initialize with Rails Builder template
nix flake init -t github:glenndavy/rails-builder#rails

# 3. Create new Rails app structure
nix develop .#with-bundler --command bash -c '
  gem install rails bundler
  rails new . --skip-git --skip-bundle
'

# 4. Install dependencies
nix develop .#with-bundler --command bundle install

# 5. Enter development shell
nix develop .#with-bundler

# 6. Start services and server
manage-postgres start
rails s
```

### Option 2: New Hanami Application

```bash
# 1. Create project directory
mkdir my-hanami-app && cd my-hanami-app

# 2. Use auto-detecting template
nix flake init -t github:glenndavy/rails-builder#ruby

# 3. Create Hanami app
nix develop .#with-bundler --command bash -c '
  gem install hanami bundler
  hanami new . --skip-git
'

# 4. Install and develop
nix develop .#with-bundler --command bundle install
nix develop .#with-bundler
```

### Option 3: New Sinatra Application

```bash
# 1. Create project directory
mkdir my-sinatra-app && cd my-sinatra-app

# 2. Use auto-detecting template
nix flake init -t github:glenndavy/rails-builder#ruby

# 3. Create basic Sinatra structure
nix develop .#with-bundler --command bash -c '
  echo "source '\''https://rubygems.org'\''" > Gemfile
  echo "gem '\''sinatra'\''" >> Gemfile
  echo "gem '\''rackup'\''" >> Gemfile
  echo "require '\''sinatra'\''; get '\''/'\'' { '\''Hello World!'\'' }" > app.rb
  echo "require '\''./app'\''; run Sinatra::Application" > config.ru
'

# 4. Install dependencies and start
nix develop .#with-bundler --command bundle install
nix develop .#with-bundler
manage-postgres start  # If you add database gems
rackup
```

## Existing Application Setup

### For Existing Rails/Ruby Projects

```bash
# 1. In your existing project directory
nix flake init -t github:glenndavy/rails-builder#rails
# OR for auto-detection:
nix flake init -t github:glenndavy/rails-builder#ruby

# 2. Install dependencies
nix develop .#with-bundler --command bundle install

# 3. Enter development shell
nix develop .#with-bundler

# 4. Start services and develop
manage-postgres start
manage-redis start      # If needed
bundle exec rails s     # Or your app's start command
```

## Development Environments

Rails Builder provides multiple development environments:

### `with-bundler` (Recommended)
**Traditional bundler approach - works on all platforms**

```bash
nix develop .#with-bundler
```

**Features:**
- Uses `bundle exec` commands
- Gems isolated in `./vendor/bundle`
- Compatible with macOS and Linux
- Database services included
- PostgreSQL and Redis management scripts

**Shell shows:**
```
🔧 Traditional bundler environment:
   bundle install  - Install gems to ./vendor/bundle
   bundle exec     - Run commands with bundler
   rails s         - Start server (via bundle exec)
   Gems isolated in: ./vendor/bundle

🗄️ Database & Services:
   manage-postgres start - Start PostgreSQL server
   manage-postgres help  - Show PostgreSQL connection info
   manage-redis start    - Start Redis server
```

### `with-bundix` (Advanced)
**Pure Nix approach - Linux optimized**

```bash
# First generate gemset.nix
nix develop .#with-bundler --command bundix

# Then use pure Nix environment
nix develop .#with-bundix
```

**Features:**
- Direct gem access (no `bundle exec` needed)
- Gems served from Nix store
- Faster execution
- Requires `gemset.nix` generation
- Database services included

**Shell shows:**
```
🔧 Nix bundlerEnv environment:
   rails s         - Start server (direct, no bundle exec)
   bundix          - Generate gemset.nix from Gemfile.lock
   fix-gemset-sha  - Fix SHA mismatches in gemset.nix

🗄️ Database & Services:
   manage-postgres start - Start PostgreSQL server
   manage-postgres help  - Show PostgreSQL connection info
   manage-redis start    - Start Redis server
   Gems accessed directly from Nix store (no bundle exec needed)
```

## Database Services

Rails Builder includes PostgreSQL and Redis management for local development with flexible port configuration.

### PostgreSQL

#### Basic Usage
```bash
# Get help and connection info
manage-postgres help

# Start PostgreSQL server (default port 5432)
manage-postgres start

# Stop PostgreSQL server
manage-postgres stop
```

#### Custom Port Usage
```bash
# Start on custom port
manage-postgres start --port 5433

# Get connection info for custom port
manage-postgres help --port 5433

# Stop (works regardless of port)
manage-postgres stop
```

#### Connection Information

**Default Configuration:**
- **Database:** `rails_build`
- **User:** Your Unix username (no password needed)
- **Host:** Unix socket in `./tmp/`
- **Port:** `5432` (default)
- **DATABASE_URL:** `postgresql://yourusername@localhost:5432/rails_build?host=/path/to/project/tmp`

**Example with Custom Port:**
```bash
# Start on port 5433
manage-postgres start --port 5433

# The help shows actual connection details:
manage-postgres help --port 5433
# OUTPUT:
# CONNECTION INFO:
#   Database: rails_build
#   User: yourusername (current Unix user)
#   Port: 5433
#
# DATABASE_URL:
#   postgresql://yourusername@localhost:5433/rails_build?host=/path/to/project/tmp
#
# DIRECT CONNECTION COMMANDS:
#   psql -h /path/to/project/tmp -p 5433 -d rails_build
```

#### Direct Connection Examples
```bash
# Default port (5432)
psql -h ./tmp -d rails_build

# Custom port (5433)
psql -h ./tmp -p 5433 -d rails_build

# Using DATABASE_URL (copy from help output)
psql "postgresql://yourusername@localhost:5433/rails_build?host=/path/to/project/tmp"
```

### Redis

#### Basic Usage
```bash
# Get help and connection info
manage-redis help

# Start Redis server (default port 6379)
manage-redis start

# Stop Redis server
manage-redis stop
```

#### Custom Port Usage
```bash
# Start on custom port
manage-redis start --port 6380

# Get connection info for custom port
manage-redis help --port 6380

# Stop (works regardless of port)
manage-redis stop
```

#### Connection Information

**Default Configuration:**
- **Host:** `localhost`
- **Port:** `6379` (default)
- **Database:** `0` (default Redis database)
- **REDIS_URL:** `redis://localhost:6379/0`

**Example with Custom Port:**
```bash
# Start on port 6380
manage-redis start --port 6380

# The help shows actual connection details:
manage-redis help --port 6380
# OUTPUT:
# CONNECTION INFO:
#   Host: localhost
#   Port: 6380
#   Database: 0 (default)
#
# REDIS_URL:
#   redis://localhost:6380/0
#
# DIRECT CONNECTION COMMANDS:
#   redis-cli -p 6380
#   redis-cli -p 6380 ping
```

#### Direct Connection Examples
```bash
# Default port (6379)
redis-cli
redis-cli ping

# Custom port (6380)
redis-cli -p 6380
redis-cli -p 6380 ping

# Test connection
redis-cli -p 6380 ping
# Should return: PONG
```

### Multiple Environment Setup

The `--port` feature allows running multiple database instances simultaneously:

```bash
# Terminal 1: Main development environment
nix develop .#with-bundler
manage-postgres start                    # Port 5432
manage-redis start                       # Port 6379
rails s                                  # Port 3000

# Terminal 2: Test environment
nix develop .#with-bundler
manage-postgres start --port 5433        # Different PostgreSQL port
manage-redis start --port 6380           # Different Redis port

# Set environment variables for test
export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
export REDIS_URL="redis://localhost:6380/0"
rails s -p 3001                         # Different Rails port
```

### Rails Database Setup

```bash
# After starting PostgreSQL
manage-postgres start

# Standard Rails database setup
bundle exec rake db:create db:migrate db:seed

# Or for new apps
bundle exec rails db:setup
```

## Framework Auto-Detection (Ruby Template)

When using the `#ruby` template, Rails Builder automatically detects your framework and includes only necessary dependencies:

| Framework | Detection Method | Entry Point |
|-----------|------------------|-------------|
| **Rails** | `config/application.rb` + `rails` gem | `rails s` |
| **Hanami** | `config/app.rb` + `hanami` gem | `hanami server` |
| **Sinatra** | `config.ru` + `sinatra` gem | `rackup` |
| **Rack** | `config.ru` (generic) | `rackup` |
| **Ruby + Rake** | `Rakefile` | Custom |
| **Plain Ruby** | Default fallback | Custom |

**Smart Dependencies:**
- **Database:** Only includes PostgreSQL if `pg` gem detected
- **Cache:** Only includes Redis if `redis*` gems detected
- **Assets:** Only includes Node.js if asset gems detected
- **Build Tools:** Always included for native extensions

## Production Builds

### Build Application Packages

```bash
# Traditional bundler build
nix build .#package-with-bundler

# Pure Nix build (requires gemset.nix)
nix build .#package-with-bundix
```

### Build Docker Images

```bash
# Docker with bundler approach
nix build .#docker-with-bundler

# Docker with bundlerEnv approach
nix build .#docker-with-bundix

# Load and run
docker load < result
docker run -p 3000:3000 your-app:tag
```

## Advanced Usage

### Generate Nix Dependencies

```bash
# Generate gemset.nix for bundix approach
nix run .#generate-dependencies
# OR
nix develop .#with-bundler --command bundix
```

### Fix SHA Mismatches

```bash
# Auto-fix common gem SHA issues
nix run .#fix-gemset-sha
```

### Check Ruby/Bundler Versions

```bash
# Show Ruby version
nix run .#detectRubyVersion

# Show Bundler version
nix run .#detectBundlerVersion

# Show flake version
nix run .#flakeVersion
```

### Cross-Platform Builds

```bash
# Build for different architectures
nix build .#package-with-bundler --system x86_64-linux
nix build .#package-with-bundler --system aarch64-darwin
```

## Common Workflows

### Daily Development

```bash
# 1. Enter development shell
nix develop .#with-bundler

# 2. Start services
manage-postgres start
manage-redis start

# 3. Update dependencies (if needed)
bundle update && bundle install

# 4. Database migrations (if any)
bundle exec rake db:migrate

# 5. Start server
bundle exec rails s

# 6. Open http://localhost:3000
```

### Adding Database Gems

```bash
# Add to Gemfile
echo "gem 'pg'" >> Gemfile

# Install and restart shell for detection
bundle install
exit
nix develop .#with-bundler  # PostgreSQL tools now available
```

### Switching Between Environments

```bash
# Start with traditional bundler
nix develop .#with-bundler

# Generate gemset.nix
bundix

# Switch to pure Nix
exit
nix develop .#with-bundix  # Direct gem access, no bundle exec
```

### Multi-Environment Development

Use custom ports to run multiple environments simultaneously:

```bash
# Development Environment (Terminal 1)
nix develop .#with-bundler
manage-postgres start                # Default port 5432
manage-redis start                   # Default port 6379
bundle exec rake db:create db:migrate
rails s                             # Port 3000

# Testing Environment (Terminal 2)
nix develop .#with-bundler
manage-postgres start --port 5433    # Custom PostgreSQL port
manage-redis start --port 6380       # Custom Redis port

# Configure Rails for test environment
export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
export REDIS_URL="redis://localhost:6380/0"
export RAILS_ENV=test

bundle exec rake db:create db:migrate
rails s -p 3001                     # Port 3001

# Staging Environment (Terminal 3)
nix develop .#with-bundler
manage-postgres start --port 5434    # Another PostgreSQL port
export DATABASE_URL="postgresql://$(whoami)@localhost:5434/rails_build?host=$PWD/tmp"
export RAILS_ENV=staging
rails s -p 3002                     # Port 3002
```

### Port Conflict Resolution

If default ports are already in use:

```bash
# Check what's using ports
lsof -i :5432  # PostgreSQL
lsof -i :6379  # Redis
lsof -i :3000  # Rails

# Start services on available ports
manage-postgres start --port 5433
manage-redis start --port 6380
rails s -p 3001

# Update application configuration
export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
export REDIS_URL="redis://localhost:6380/0"
```

### Testing

```bash
# Run tests in isolated environment with custom ports
nix develop .#with-bundler --command bash -c '
  manage-postgres start --port 5433
  manage-redis start --port 6380

  export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
  export REDIS_URL="redis://localhost:6380/0"
  export RAILS_ENV=test

  bundle exec rake db:create db:migrate
  bundle exec rspec
'
```

## Troubleshooting

### Common Issues

**"Bundle install uses system gems"**
- ✅ **Fixed!** Rails Builder now properly isolates gems in `./vendor/bundle`
- Check: `echo $BUNDLE_PATH` should show `./vendor/bundle`

**"PostgreSQL connection failed"**
```bash
# Check if service is running and get connection info
manage-postgres help  # Shows actual connection string for default port
manage-postgres help --port 5433  # For custom port

# Check running processes
ps aux | grep postgres
lsof -i :5432  # Check if port is in use

# Restart if needed
manage-postgres stop
manage-postgres start

# Or restart on custom port
manage-postgres start --port 5433
```

**"Port already in use" errors**
```bash
# Check what's using the ports
lsof -i :5432  # PostgreSQL default
lsof -i :6379  # Redis default
netstat -tuln | grep 5432

# Use custom ports
manage-postgres start --port 5433
manage-redis start --port 6380

# Update your application configuration
export DATABASE_URL="postgresql://$(whoami)@localhost:5433/rails_build?host=$PWD/tmp"
export REDIS_URL="redis://localhost:6380/0"
```

**"Redis connection failed"**
```bash
# Check if Redis is running
manage-redis help --port 6379  # Default port
manage-redis help --port 6380  # Custom port

# Test connection
redis-cli ping                  # Default port
redis-cli -p 6380 ping         # Custom port

# Restart if needed
manage-redis stop
manage-redis start --port 6380
```

**"Gems not found in bundix environment"**
```bash
# Regenerate gemset.nix
nix develop .#with-bundler --command bundix

# Fix SHA mismatches
nix run .#fix-gemset-sha
```

**"Node.js not available"**
- Ruby template only includes Node.js if asset gems detected
- Add asset gems to Gemfile or use Rails template

### Getting Help

**Check Environment:**
```bash
# See what's detected
nix run .#detectFramework  # Ruby template only

# Check versions
nix run .#detectRubyVersion
nix run .#detectBundlerVersion
```

**Database Connection Info:**
```bash
manage-postgres help
# Shows exact DATABASE_URL and connection commands
```

**Shell Information:**
```bash
# Each devShell shows available commands when entered
nix develop .#with-bundler  # Shows bundler commands
nix develop .#with-bundix   # Shows bundix commands
```

## Next Steps

1. **Explore the templates** - Try both `#rails` and `#ruby` to see which fits your workflow
2. **Set up your database** - Use `manage-postgres start` for local PostgreSQL
3. **Try both environments** - Compare `with-bundler` vs `with-bundix` approaches
4. **Build for production** - Use `nix build` to create deployment artifacts

Rails Builder handles the complexity of cross-platform Ruby deployment while keeping your development environment fast, reproducible, and isolated. Happy coding! 🚀