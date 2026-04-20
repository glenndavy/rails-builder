#!/usr/bin/env bash
# Generate tailwindcss npm deps hash for a specific version
# Must be run on each target architecture (x86_64-linux, aarch64-linux)
#
# Usage: ./generate-tailwindcss-hash.sh 4.1.18       # single version
#        ./generate-tailwindcss-hash.sh --all         # all missing versions from npm
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/tailwindcss-hashes.nix"
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')

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
FLAKE_TMPDIR=$(mktemp -d)
trap "rm -rf $FLAKE_TMPDIR" EXIT

cat > "$FLAKE_TMPDIR/flake.nix" << 'FLAKEEOF'
{
  inputs.nixpkgs.url = "NIXPKGS_URL_PLACEHOLDER";
  outputs = { nixpkgs, ... }: let
    system = builtins.currentSystem;
    pkgs = import nixpkgs { inherit system; };
    version = builtins.getEnv "TAILWIND_VERSION";
  in {
    packages.${system}.default = pkgs.runCommand "tailwindcss-npm-deps-${version}" {
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = pkgs.lib.fakeHash;
      nativeBuildInputs = [ pkgs.bun pkgs.cacert ];
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    } ''
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      mkdir -p $out && cd $out
      echo '{"dependencies":{"@tailwindcss/cli":"${version}"}}' > package.json
      ${pkgs.bun}/bin/bun install --production
      rm -rf $out/.bun-cache $out/bun.lockb 2>/dev/null || true
    '';
  };
}
FLAKEEOF

sed -i "s|NIXPKGS_URL_PLACEHOLDER|$NIXPKGS_URL|" "$FLAKE_TMPDIR/flake.nix"

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

# Generate hash for a single version, returns hash via GENERATED_HASH variable
# Reuses the pre-built temp flake in $FLAKE_TMPDIR
generate_hash() {
  local version="$1"
  GENERATED_HASH=""

  echo "Generating tailwindcss hash for version $version on $SYSTEM..."

  # Build and capture the hash from the error
  local logfile="$FLAKE_TMPDIR/build-output.log"
  (cd "$FLAKE_TMPDIR" && TAILWIND_VERSION="$version" nix build --impure .#default 2>&1 | tee "$logfile" || true)
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
  echo "Version: $version"
  echo "System:  $SYSTEM"
  echo "Hash:    $hash"
}

# --- Main ---

if [ "${1:-}" = "--all" ]; then
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

elif [ -n "${1:-}" ]; then
  VERSION="$1"

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
  echo "Usage: $0 <version>     # generate hash for one version"
  echo "       $0 --all         # generate hashes for all missing npm versions"
  exit 1
fi
