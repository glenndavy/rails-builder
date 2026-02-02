# Rails Builder Orchestration Options

This document explains the different ways to integrate rails-builder with your Ruby/Rails applications. Choose the approach that best fits your project structure and deployment needs.

## Overview

| Option | App Repo Contains | Best For |
|--------|------------------|----------|
| **1. Direct Template** | flake.nix, gemset.nix | Single apps, full Nix integration |
| **2. Build Input** | flake.nix, gemset.nix | Apps that need custom flake configuration |
| **3. Orchestrator** | Nothing (clean source) | Multi-app deployments, CI/CD pipelines |

---

## Option 1: Direct Template

Use rails-builder's template directly in your app repository. This is the simplest approach for single applications.

### Setup

```bash
cd my-rails-app
nix flake init -t github:glenndavy/rails-builder#universal
```

### Structure

```
my-rails-app/
├── app/
├── config/
├── Gemfile
├── Gemfile.lock
├── flake.nix        # Generated from template
├── flake.lock
└── gemset.nix       # Generated with bundix
```

### Usage

```bash
# Development
nix develop .#with-bundler      # Traditional bundler workflow
nix develop .#with-bundix       # Direct gem access (no bundle exec)

# Generate/update gemset.nix
nix develop .#with-bundix-bootstrap
bundix

# Build
nix build .#package-with-bundix
nix build .#docker-with-bundix
```

### Pros
- Simplest setup
- Self-contained - everything in one repo
- Works immediately after `nix flake init`

### Cons
- Adds Nix files to app repository
- Each app manages its own flake configuration

---

## Option 2: Build Input

Your app has its own flake.nix that imports rails-builder as an input. This gives you full control over the flake configuration while leveraging rails-builder's functionality.

### Setup

Create a `flake.nix` in your app repository:

```nix
{
  description = "My Rails Application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, rails-builder, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nixpkgs-ruby.overlays.default ];
    };
  in {
    packages.${system} = rec {
      default = app;

      app = (rails-builder.lib.${system}.mkRailsPackage {
        inherit pkgs;
        src = ./.;
        appName = "my-rails-app";
        # gemset.nix is read from src automatically
      }).app;

      dockerImage = (rails-builder.lib.${system}.mkRailsPackage {
        inherit pkgs;
        src = ./.;
        appName = "my-rails-app";
      }).dockerImage;
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        rails-builder.packages.${system}.bundix
        # ... your other dev dependencies
      ];
    };
  };
}
```

### Structure

```
my-rails-app/
├── app/
├── config/
├── Gemfile
├── Gemfile.lock
├── flake.nix        # Custom flake using rails-builder
├── flake.lock
└── gemset.nix       # Generated with bundix
```

### Usage

```bash
# Generate gemset.nix
nix develop github:glenndavy/rails-builder#with-bundix-bootstrap
bundix

# Build
nix build .#app
nix build .#dockerImage
```

### Pros
- Full control over flake configuration
- Can add custom packages, shells, and apps
- Can integrate with other Nix tooling

### Cons
- More setup than Option 1
- Still requires Nix files in app repo

---

## Option 3: Orchestrator Repository

Keep app repositories clean (no Nix files) by managing all builds from a separate orchestrator repository. This is ideal for organizations with multiple apps or CI/CD pipelines.

### Setup

Create a separate orchestrator repository:

```nix
# orchestrator-repo/flake.nix
{
  description = "Rails Application Builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
    nixpkgs-ruby.inputs.nixpkgs.follows = "nixpkgs";
    rails-builder.url = "github:glenndavy/rails-builder";

    # App sources as non-flake inputs
    ops-core = {
      url = "github:yourorg/ops-core";
      flake = false;
    };
    billing-api = {
      url = "github:yourorg/billing-api";
      flake = false;
    };
    admin-portal = {
      url = "github:yourorg/admin-portal";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-ruby, rails-builder, ops-core, billing-api, admin-portal, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ nixpkgs-ruby.overlays.default ];
    };

    # Helper to build a Rails app
    mkApp = { src, gemset, name }:
      rails-builder.lib.${system}.mkRailsPackage {
        inherit pkgs src gemset;
        appName = name;
      };

  in {
    packages.${system} = {
      # Ops Core
      ops-core = (mkApp {
        src = ops-core;
        gemset = ./apps/ops-core/gemset.nix;
        name = "ops-core";
      }).app;

      ops-core-docker = (mkApp {
        src = ops-core;
        gemset = ./apps/ops-core/gemset.nix;
        name = "ops-core";
      }).dockerImage;

      # Billing API
      billing-api = (mkApp {
        src = billing-api;
        gemset = ./apps/billing-api/gemset.nix;
        name = "billing-api";
      }).app;

      billing-api-docker = (mkApp {
        src = billing-api;
        gemset = ./apps/billing-api/gemset.nix;
        name = "billing-api";
      }).dockerImage;

      # Admin Portal
      admin-portal = (mkApp {
        src = admin-portal;
        gemset = ./apps/admin-portal/gemset.nix;
        name = "admin-portal";
      }).app;

      admin-portal-docker = (mkApp {
        src = admin-portal;
        gemset = ./apps/admin-portal/gemset.nix;
        name = "admin-portal";
      }).dockerImage;
    };
  };
}
```

### Structure

```
orchestrator-repo/
├── flake.nix
├── flake.lock
└── apps/
    ├── ops-core/
    │   └── gemset.nix
    ├── billing-api/
    │   └── gemset.nix
    └── admin-portal/
        └── gemset.nix

# App repos remain clean:
ops-core/
├── app/
├── config/
├── Gemfile
├── Gemfile.lock
└── (no Nix files!)
```

### Generating gemset.nix

Use the `generate-gemset-for` app to create/update gemset.nix files:

```bash
# From orchestrator repo directory
nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/ops-core -o ./apps/ops-core/gemset.nix
nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/billing-api -o ./apps/billing-api/gemset.nix

# Or if apps are checked out locally
nix run github:glenndavy/rails-builder#generate-gemset-for -- ~/code/ops-core -o ./apps/ops-core/gemset.nix

# Commit the updated gemset
git add apps/ops-core/gemset.nix
git commit -m "Update ops-core gemset.nix"
```

### Building

```bash
# Build specific app
nix build .#ops-core
nix build .#ops-core-docker

# Build all
nix build .#ops-core-docker .#billing-api-docker .#admin-portal-docker
```

### CI/CD Integration

```yaml
# .github/workflows/build.yml
name: Build Apps
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      app:
        description: 'App to build (or "all")'
        required: true
        default: 'all'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v24
      - uses: cachix/cachix-action@v14
        with:
          name: your-cache
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'

      - name: Build ops-core
        if: inputs.app == 'all' || inputs.app == 'ops-core'
        run: nix build .#ops-core-docker

      - name: Build billing-api
        if: inputs.app == 'all' || inputs.app == 'billing-api'
        run: nix build .#billing-api-docker
```

### Updating Apps

When an app's dependencies change:

```bash
# 1. Update the app input to get latest source
nix flake lock --update-input ops-core

# 2. Regenerate gemset.nix (if Gemfile.lock changed)
nix run github:glenndavy/rails-builder#generate-gemset-for -- \
  $(nix eval --raw .#inputs.ops-core.outPath) \
  -o ./apps/ops-core/gemset.nix

# 3. Commit and push
git add flake.lock apps/ops-core/gemset.nix
git commit -m "Update ops-core"
git push
```

### Pros
- App repositories stay clean (no Nix files)
- Centralized build configuration
- Single point for CI/CD
- Easy to manage multiple apps
- Version pinning via flake.lock
- Can build specific versions by pinning inputs

### Cons
- Requires separate repository
- Two-step process to update (source + gemset)
- Need to keep gemset.nix in sync with app changes

---

## Comparison Matrix

| Feature | Option 1 (Template) | Option 2 (Build Input) | Option 3 (Orchestrator) |
|---------|---------------------|------------------------|-------------------------|
| Nix files in app repo | Yes | Yes | No |
| Setup complexity | Low | Medium | Medium |
| Customization | Limited | Full | Full |
| Multi-app management | Per-app | Per-app | Centralized |
| CI/CD integration | Per-app | Per-app | Centralized |
| Dependency updates | In-place | In-place | Two-step |
| Best for | Single apps | Custom needs | Organizations |

---

## Migrating Between Options

### Template → Build Input

1. Keep your existing `flake.nix` and `gemset.nix`
2. Modify `flake.nix` to use `mkRailsPackage` directly (see Option 2 example)

### Template → Orchestrator

1. Create orchestrator repo with your app as an input
2. Copy `gemset.nix` to orchestrator: `apps/my-app/gemset.nix`
3. Remove `flake.nix`, `flake.lock`, `gemset.nix` from app repo

### Build Input → Orchestrator

1. Create orchestrator repo
2. Move `gemset.nix` to orchestrator
3. Remove Nix files from app repo
4. Add app as flake input in orchestrator

---

## Version Detection

All options support automatic version detection from app source:

- **Ruby version**: `.ruby-version`
- **Bundler version**: `Gemfile.lock` (`BUNDLED WITH` section)
- **Node version**: `.node-version` or `.nvmrc`
- **Tailwind version**: `Gemfile.lock` (tailwindcss-ruby gem)
- **Framework**: `Gemfile.lock` + config files (Rails, Hanami, Sinatra, Rack)
- **App name**: `config/application.rb` (Rails module name)

These work automatically regardless of which option you choose.
