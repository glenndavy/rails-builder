#!/usr/bin/env bash
# Generate tailwindcss npm deps hash for a specific version
# Must be run on each target architecture (x86_64-linux, aarch64-linux)
# or use --system to cross-generate via QEMU binfmt emulation
#
# This script generates a bun.lockb lockfile AND the corresponding npm deps hash
# as a pair, ensuring transitive dependencies are pinned for reproducibility.
#
# Usage: ./generate-tailwindcss-hash.sh 4.1.18                          # single version
#        ./generate-tailwindcss-hash.sh --all                            # all missing versions
#        ./generate-tailwindcss-hash.sh --all --system aarch64-linux     # cross-generate
#        ./generate-tailwindcss-hash.sh 4.2.2 --system aarch64-linux    # single + cross
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/tailwindcss-hashes.nix"
LOCKS_DIR="$SCRIPT_DIR/tailwindcss-locks"

# Ensure locks directory exists
mkdir -p "$LOCKS_DIR"

# Parse arguments: positional arg (version or --all) and optional --system
MODE=""
VERSION=""
SYSTEM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --system)
      SYSTEM="$2"
      shift 2
      ;;
    *)
      VERSION="$1"
      MODE="single"
      shift
      ;;
  esac
done

# Default system to current if not specified
if [ -z "$SYSTEM" ]; then
  SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')
fi

# Get the nixpkgs rev from our flake.lock so we use cached binaries
NIXPKGS_REV=$(nix eval --raw --impure --expr "
  let lock = builtins.fromJSON (builtins.readFile $SCRIPT_DIR/flake.lock);
  in lock.nodes.nixpkgs.locked.rev
" 2>/dev/null) || ""

if [ -z "$NIXPKGS_REV" ]; then
  NIXPKGS_URL="github:NixOS/nixpkgs/nixos-unstable"
else
  NIXPKGS_URL="github:NixOS/nixpkgs/$NIXPKGS_REV"
fi

# Create temp flake directory once — reused across all generate_hash calls
# Uses TARGET_SYSTEM env var instead of builtins.currentSystem
FLAKE_TMPDIR=$(mktemp -d)
trap "rm -rf $FLAKE_TMPDIR" EXIT

# Write the temp flake — it will be updated per-version with lockfile path
write_temp_flake() {
  local lockfile_path="$1"  # empty string if no lockfile

  if [ -n "$lockfile_path" ]; then
    cat > "$FLAKE_TMPDIR/flake.nix" << FLAKEEOF
{
  inputs.nixpkgs.url = "$NIXPKGS_URL";
  outputs = { nixpkgs, ... }: let
    system = builtins.getEnv "TARGET_SYSTEM";
    pkgs = import nixpkgs { inherit system; };
    version = builtins.getEnv "TAILWIND_VERSION";
    lockfile = $lockfile_path;
  in {
    packages.\${system}.default = pkgs.runCommand "tailwindcss-npm-deps-\${version}" {
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = pkgs.lib.fakeHash;
      nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
      SSL_CERT_FILE = "\${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    } ''
      export HOME=\$TMPDIR
      export BUN_INSTALL_CACHE_DIR=\$TMPDIR/bun-cache
      mkdir -p \$out && cd \$out
      echo '{"dependencies":{"@tailwindcss/cli":"\${version}"}}' > package.json
      cp \${lockfile} bun.lockb
      \${pkgs.bun}/bin/bun install --frozen-lockfile --production
      rm -rf \$out/.bun-cache \$out/bun.lockb 2>/dev/null || true
    '';
  };
}
FLAKEEOF
  else
    cat > "$FLAKE_TMPDIR/flake.nix" << FLAKEEOF
{
  inputs.nixpkgs.url = "$NIXPKGS_URL";
  outputs = { nixpkgs, ... }: let
    system = builtins.getEnv "TARGET_SYSTEM";
    pkgs = import nixpkgs { inherit system; };
    version = builtins.getEnv "TAILWIND_VERSION";
  in {
    packages.\${system}.default = pkgs.runCommand "tailwindcss-npm-deps-\${version}" {
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = pkgs.lib.fakeHash;
      nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
      SSL_CERT_FILE = "\${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    } ''
      export HOME=\$TMPDIR
      export BUN_INSTALL_CACHE_DIR=\$TMPDIR/bun-cache
      mkdir -p \$out && cd \$out
      echo '{"dependencies":{"@tailwindcss/cli":"\${version}"}}' > package.json
      \${pkgs.bun}/bin/bun install --production
      rm -rf \$out/.bun-cache \$out/bun.lockb 2>/dev/null || true
    '';
  };
}
FLAKEEOF
  fi

  # Remove old flake.lock so nix re-resolves
  rm -f "$FLAKE_TMPDIR/flake.lock"
}

# Check if a version+system already has a hash in tailwindcss-hashes.nix
has_hash() {
  local version="$1"
  local system="$2"
  # Extract the block for this version, then check for the system within it
  if grep -q "\"$version\"" "$HASHES_FILE" && \
     awk -v ver="\"$version\"" '
       $0 ~ ver { found=1; depth=0 }
       found && /{/ { depth++ }
       found && /}/ { depth--; if (depth<=0) { found=0 } }
       found { print }
     ' "$HASHES_FILE" | grep -q "\"$system\".*sha256-"; then
    return 0
  fi
  return 1
}

# Update tailwindcss-hashes.nix with a new hash
update_hashes_file() {
  local version="$1"
  local system="$2"
  local hash="$3"

  if grep -q "\"$version\"" "$HASHES_FILE"; then
    # Version exists — check if system is already there
    if has_hash "$version" "$system"; then
      echo "  Hash for $version/$system already in file, updating..."
      # Find the version line, then the first matching system line after it
      local ver_line
      ver_line=$(grep -n "\"$version\"" "$HASHES_FILE" | head -1 | cut -d: -f1)
      local sys_line
      sys_line=$(tail -n +"$ver_line" "$HASHES_FILE" | grep -n "\"$system\"" | head -1 | cut -d: -f1)
      sys_line=$((ver_line + sys_line - 1))
      sed -i "${sys_line}s|\"$system\" = \"sha256-[^\"]*\";|\"$system\" = \"$hash\";|" "$HASHES_FILE"
    else
      # Add system entry — find the first }; after the version line (closes npmDeps)
      local ver_line
      ver_line=$(grep -n "\"$version\"" "$HASHES_FILE" | head -1 | cut -d: -f1)
      local insert_line
      insert_line=$(tail -n +"$ver_line" "$HASHES_FILE" | grep -n '};' | head -1 | cut -d: -f1)
      insert_line=$((ver_line + insert_line - 1))
      sed -i "${insert_line}i\\      \"$system\" = \"$hash\";" "$HASHES_FILE"
    fi
  else
    # New version — build the block and insert before the closing }
    local new_block
    new_block="  \"$version\" = {\n    npmDeps = {\n      \"$system\" = \"$hash\";\n    };\n  };"
    sed -i "/^}$/i\\$new_block" "$HASHES_FILE"
  fi
}

# Generate lockfile for a version using bun install outside Nix
# This captures the exact transitive dependency resolution
generate_lockfile() {
  local version="$1"
  local lockfile_dest="$LOCKS_DIR/${version}.lockb"

  if [ -f "$lockfile_dest" ]; then
    echo "  Lockfile already exists at $lockfile_dest, reusing..."
    return 0
  fi

  echo "  Generating lockfile for @tailwindcss/cli@${version}..."
  local lockdir="$FLAKE_TMPDIR/lockgen-${version}"
  mkdir -p "$lockdir"

  # Create package.json and run bun install to generate bun.lockb
  echo "{\"dependencies\":{\"@tailwindcss/cli\":\"${version}\"}}" > "$lockdir/package.json"

  # Use nix-shell to get bun, then run bun install
  # This runs outside the Nix build sandbox so it has network access
  (cd "$lockdir" && nix shell "nixpkgs#bun" -c bun install --production 2>&1) || {
    echo "ERROR: bun install failed for version $version"
    return 1
  }

  if [ ! -f "$lockdir/bun.lockb" ]; then
    echo "ERROR: bun.lockb was not generated for version $version"
    return 1
  fi

  cp "$lockdir/bun.lockb" "$lockfile_dest"
  echo "  Saved lockfile to $lockfile_dest"
}

# Generate hash for a single version, returns hash via GENERATED_HASH variable
# Generates lockfile first, then uses it in the Nix build for reproducibility
generate_hash() {
  local version="$1"
  GENERATED_HASH=""

  echo "Generating tailwindcss lockfile + hash for version $version on $SYSTEM..."

  # Step 1: Generate lockfile (if not already present)
  generate_lockfile "$version" || return 1

  local lockfile_dest="$LOCKS_DIR/${version}.lockb"

  # Step 2: Write temp flake that uses the lockfile with --frozen-lockfile
  # Copy lockfile into temp flake dir so Nix can access it
  cp "$lockfile_dest" "$FLAKE_TMPDIR/bun-lock-${version}.lockb"
  write_temp_flake "./bun-lock-${version}.lockb"

  # Step 3: Build and capture the hash from the error
  local logfile="$FLAKE_TMPDIR/build-output.log"
  (cd "$FLAKE_TMPDIR" && TARGET_SYSTEM="$SYSTEM" TAILWIND_VERSION="$version" nix build --impure ".#packages.${SYSTEM}.default" 2>&1 | tee "$logfile" || true)
  local output
  output=$(cat "$logfile")

  # Extract the hash from "got: sha256-..."
  local hash
  hash=$(echo "$output" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)

  if [ -z "$hash" ]; then
    echo "ERROR: Could not extract hash for version $version"
    echo "$output" | tail -20
    return 1
  fi

  GENERATED_HASH="$hash"
  echo ""
  echo "=== Result ==="
  echo "Version:  $version"
  echo "System:   $SYSTEM"
  echo "Hash:     $hash"
  echo "Lockfile: $lockfile_dest"
}

# --- Main ---

if [ "$MODE" = "all" ]; then
  echo "Querying npm for all @tailwindcss/cli versions..."
  ALL_VERSIONS=$(curl -s 'https://registry.npmjs.org/@tailwindcss/cli' | jq -r '.versions | keys[]')

  if [ -z "$ALL_VERSIONS" ]; then
    echo "ERROR: Could not fetch versions from npm registry"
    exit 1
  fi

  # Filter to stable v4+ only (skip alpha/beta/rc pre-releases)
  VERSIONS=$(echo "$ALL_VERSIONS" | grep '^4\.' | grep -v -E '(alpha|beta|rc)' || true)

  if [ -z "$VERSIONS" ]; then
    echo "No v4.x versions found"
    exit 0
  fi

  total=$(echo "$VERSIONS" | wc -l)
  echo "Found $total v4.x versions on npm"
  echo "System: $SYSTEM"
  echo "Using nixpkgs: $NIXPKGS_URL"
  echo ""

  skipped=0
  generated=0
  failed=0

  while IFS= read -r version; do
    if has_hash "$version" "$SYSTEM"; then
      echo "SKIP $version ($SYSTEM already present)"
      skipped=$((skipped + 1))
      continue
    fi

    echo ""
    echo "--- Processing $version ---"
    if generate_hash "$version"; then
      update_hashes_file "$version" "$SYSTEM" "$GENERATED_HASH"
      echo "Updated tailwindcss-hashes.nix with $version/$SYSTEM"
      generated=$((generated + 1))
    else
      echo "FAILED to generate hash for $version"
      failed=$((failed + 1))
    fi
  done <<< "$VERSIONS"

  echo ""
  echo "=== Summary ==="
  echo "Skipped (already present): $skipped"
  echo "Generated: $generated"
  echo "Failed: $failed"

elif [ "$MODE" = "single" ]; then
  echo "Using nixpkgs: $NIXPKGS_URL"

  if has_hash "$VERSION" "$SYSTEM"; then
    echo "Hash for $VERSION/$SYSTEM already exists in tailwindcss-hashes.nix"
    echo "Re-generating anyway..."
  fi

  generate_hash "$VERSION"
  update_hashes_file "$VERSION" "$SYSTEM" "$GENERATED_HASH"
  echo ""
  echo "Updated tailwindcss-hashes.nix with $VERSION/$SYSTEM"

else
  echo "Usage: $0 <version> [--system SYSTEM]     # generate lockfile + hash for one version"
  echo "       $0 --all [--system SYSTEM]          # generate for all missing npm versions"
  echo ""
  echo "This script generates a bun.lockb lockfile (in tailwindcss-locks/) and the"
  echo "corresponding npm deps hash (in tailwindcss-hashes.nix) as a pair."
  echo "The lockfile pins transitive dependencies for reproducible builds."
  echo ""
  echo "SYSTEM defaults to current ($(nix eval --raw --impure --expr 'builtins.currentSystem' 2>/dev/null))"
  echo "Use --system aarch64-linux to cross-generate via QEMU binfmt emulation"
  exit 1
fi
