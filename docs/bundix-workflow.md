# Bundix Workflow Guide

This guide explains how to use `bundix` with Rails Builder templates to manage Ruby gems using Nix.

## Overview

The `build-rails-with-nix` template uses Nix's `bundlerEnv` to manage Ruby gems instead of traditional bundler. This provides reproducible builds but requires a `gemset.nix` file generated from your `Gemfile.lock`.

## Workflow

### 1. Initial Setup

```bash
# Start with a normal Rails Gemfile
echo 'source "https://rubygems.org"' > Gemfile
echo 'gem "rails"' >> Gemfile
echo 'gem "nokogiri"' >> Gemfile

# Generate Gemfile.lock
bundle install

# Generate gemset.nix from Gemfile.lock
bundix
```

### 2. Fixing SHA Mismatches

Bundix sometimes generates incorrect SHA hashes, especially for platform-specific gems like Nokogiri. When you get errors like:

```
error: hash mismatch in fixed-output derivation '/nix/store/...-nokogiri-1.18.8.gem.drv':
         specified: sha256-NrrdLrKB/KYhSlGI4ko0OZsV2JcwY5oGjRKTHircIQ4=
```

**Solution:**

```bash
# Fix SHA mismatches automatically
fix-gemset-sha

# Or fix specific gems from error output
nix build 2>&1 | fix-gemset-sha
```

### 3. Adding New Gems

```bash
# 1. Add gem to Gemfile
echo 'gem "devise"' >> Gemfile

# 2. Update Gemfile.lock
bundle install

# 3. Regenerate gemset.nix
bundix

# 4. Fix any SHA mismatches
fix-gemset-sha

# 5. Test the build
nix develop .#dev
```

### 4. Complete Dependency Generation

For projects with both Ruby and JavaScript dependencies:

```bash
# Generate both gemset.nix and yarn dependencies
generate-dependencies
```

## Available Tools

When in the `build-rails-with-nix` dev shell:

- **`bundix`** - Generate/update `gemset.nix` from `Gemfile.lock`
- **`fix-gemset-sha`** - Automatically fix SHA hash mismatches
- **`generate-dependencies`** - Generate both Ruby and Node.js dependencies

## Troubleshooting

### Common Issues

1. **SHA Mismatches**: Use `fix-gemset-sha` to automatically resolve
2. **Missing Platform Gems**: Bundix might miss platform-specific versions
3. **Git-based Gems**: May require manual intervention in `gemset.nix`

### Manual SHA Fixing

If the automatic fix doesn't work:

```bash
# Get correct SHA manually
nix-prefetch-url https://rubygems.org/downloads/nokogiri-1.18.8.gem

# Update gemset.nix manually with the correct SHA
```

### Platform-Specific Gems

For gems with platform-specific versions, you may need to manually specify the platform in `gemset.nix`:

```nix
nokogiri = {
  dependencies = ["racc"];
  groups = ["default"];
  platforms = ["ruby"];  # Add this line
  source = {
    remotes = ["https://rubygems.org"];
    sha256 = "correct-sha-here";
    type = "gem";
  };
  version = "1.18.8";
};
```

## Benefits of Nix-based Gem Management

- **Reproducible builds**: Exact same versions across environments
- **No bundler needed at runtime**: Gems are in Nix store
- **Better caching**: Nix can cache individual gems
- **Integration with system deps**: Native dependencies handled by Nix

## Migration from Traditional Bundler

To migrate an existing Rails app:

1. Keep your existing `Gemfile` and `Gemfile.lock`
2. Run `bundix` to generate `gemset.nix`
3. Fix any SHA mismatches with `fix-gemset-sha`
4. Use the `build-rails-with-nix` template
5. Test with `nix develop .#dev`