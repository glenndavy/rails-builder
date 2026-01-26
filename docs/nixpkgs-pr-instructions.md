# Contributing bundlerEnv Path Resolution Fix to nixpkgs

## Problem

The nixpkgs `bundlerEnv` doesn't resolve relative paths in `type = "path"` gems. When using `bundle cache --all` with git gems, the gemset.nix contains entries like:

```nix
source = {
  path = "./vendor/cache/some-gem-abc123";
  type = "path";
};
```

The current `pathDerivation` in nixpkgs just uses `outPath = "${path}"` which doesn't work for relative paths.

## The Fix

Update `pkgs/development/ruby-modules/bundled-common/functions.nix` to resolve paths relative to gemdir.

## Steps

### 1. Fork & Clone

```bash
# Fork github.com/NixOS/nixpkgs on GitHub, then:
git clone git@github.com:YOUR_USERNAME/nixpkgs.git
cd nixpkgs
git remote add upstream https://github.com/NixOS/nixpkgs.git
```

### 2. Create a branch from master

```bash
git fetch upstream
git checkout -b fix/bundler-env-path-resolution upstream/master
```

### 3. Make the change

Edit `pkgs/development/ruby-modules/bundled-common/functions.nix`:

```nix
pathDerivation =
  {
    gemName,
    version,
    path,
    gemdir ? null,  # Add gemdir parameter
    ...
  }:
  let
    # Resolve relative paths using gemdir
    resolvedPath = if gemdir != null && builtins.isString path
      then gemdir + ("/" + path)
      else path;
    res = {
      type = "derivation";
      bundledByPath = true;
      name = gemName;
      version = version;
      outPath = "${resolvedPath}";  # Use resolvedPath
      outputs = [ "out" ];
      out = res;
      outputName = "out";
      suffix = version;
      gemType = "path";
    };
  in
  res;
```

Also update the caller in `default.nix` to pass `gemdir`:

```nix
if gemAttrs.type == "path" then
  pathDerivation (gemAttrs.source // gemAttrs // { gemdir = gemFiles.gemdir; })
else
  buildRubyGem gemAttrs
```

### 4. Test locally

```bash
# Create a test case with a path gem
nix-build -E 'with import ./. {}; bundlerEnv {
  name = "test";
  ruby = ruby;
  gemdir = ./test-gemdir;
  # ... test with path gem
}'
```

### 5. Commit with proper format

```bash
git commit -m "bundlerEnv: fix relative path resolution in pathDerivation

The pathDerivation function now resolves relative paths using the
gemdir parameter. This fixes support for vendor/cache gems created
by 'bundle cache --all' with git dependencies.

Previously, relative paths like './vendor/cache/gem-name-rev' would
fail because they weren't resolved against any base directory.
"
```

### 6. Push and create PR

```bash
git push origin fix/bundler-env-path-resolution
```

### 7. Create PR on GitHub

Title: `bundlerEnv: fix relative path resolution in pathDerivation`

Description:
```
## Problem

When using `bundle cache --all` with git gems, bundix generates gemset.nix
entries with relative paths:

    source = {
      path = "./vendor/cache/some-gem-abc123";
      type = "path";
    };

The current `pathDerivation` uses these paths directly, which doesn't work
because they're not resolved relative to any directory.

## Solution

Pass `gemdir` to `pathDerivation` and resolve relative paths against it.

## Use Case

This enables proper support for vendored git gems in Nix builds, which is
essential for:
- Offline/sandboxed builds with private git dependencies
- Reproducible builds without network access to git remotes

## Testing

Tested with a Rails application using `bundle cache --all` with a private
git gem in vendor/cache.
```

## Tips

- Check existing PRs/issues first: https://github.com/NixOS/nixpkgs/pulls?q=bundlerEnv
- Ruby modules maintainers are listed in the CODEOWNERS or module files
- PRs to nixpkgs can take time - maintainer review is thorough
- Be prepared to iterate based on feedback

## Reference

Our working implementation is in:
- `rails-builder/imports/bundler-env/`
- `rails-builder/imports/bundled-common/functions.nix`
