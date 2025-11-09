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

Rails Builder includes PostgreSQL and Redis management for local development.

### PostgreSQL

```bash
# Get help and connection info
manage-postgres help

# Start PostgreSQL server
manage-postgres start

# Stop PostgreSQL server
manage-postgres stop
```

**Connection Information:**
- **Database:** `rails_build`
- **User:** Your Unix username (no password needed)
- **Host:** Unix socket in `./tmp/`
- **DATABASE_URL:** `postgresql://yourusername@localhost/rails_build?host=/path/to/project/tmp`

**Direct Connection:**
```bash
# Using psql
psql -h ./tmp -d rails_build

# Using DATABASE_URL
psql "$(manage-postgres help | grep postgresql://)"
```

### Redis

```bash
# Start Redis server
manage-redis start

# Stop Redis server
manage-redis stop
```

**Connection:** `redis://localhost:6379`

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

### Testing

```bash
# Run tests in isolated environment
nix develop .#with-bundler --command bash -c '
  manage-postgres start
  bundle exec rake db:create db:migrate RAILS_ENV=test
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
# Check if service is running
manage-postgres help  # Shows actual connection string
ps aux | grep postgres

# Restart if needed
manage-postgres stop
manage-postgres start
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