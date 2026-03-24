#!/usr/bin/env bash
# Generate tailwindcss npm deps hash for a specific version
# Must be run on each target architecture (x86_64-linux, aarch64-linux)
#
# Usage: ./generate-tailwindcss-hash.sh 4.1.18
#
set -e

VERSION="${1:?Usage: $0 <version>}"
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')

# Get the nixpkgs rev from our flake.lock so we use cached binaries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXPKGS_REV=$(nix eval --raw --impure --expr "
  let lock = builtins.fromJSON (builtins.readFile $SCRIPT_DIR/flake.lock);
  in lock.nodes.nixpkgs.locked.rev
" 2>/dev/null) || ""

if [ -z "$NIXPKGS_REV" ]; then
  NIXPKGS_URL="github:NixOS/nixpkgs/nixos-unstable"
else
  NIXPKGS_URL="github:NixOS/nixpkgs/$NIXPKGS_REV"
fi

echo "Generating tailwindcss hash for version $VERSION on $SYSTEM..."
echo "Using nixpkgs: $NIXPKGS_URL"

# Create a temporary flake that builds tailwindcss with fake hash
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cat > "$TMPDIR/flake.nix" << 'EOF'
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
EOF

# Substitute the nixpkgs URL into the flake
sed -i "s|NIXPKGS_URL_PLACEHOLDER|$NIXPKGS_URL|" "$TMPDIR/flake.nix"

# Build and capture the hash from the error
cd "$TMPDIR"
OUTPUT=$(TAILWIND_VERSION="$VERSION" nix build --impure .#default 2>&1 || true)

# Extract the hash from "got: sha256-..."
HASH=$(echo "$OUTPUT" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' | head -1)

if [ -z "$HASH" ]; then
  echo "ERROR: Could not extract hash from build output"
  echo "$OUTPUT"
  exit 1
fi

echo ""
echo "=== Result ==="
echo "Version: $VERSION"
echo "System:  $SYSTEM"
echo "Hash:    $HASH"
echo ""
echo "Add to tailwindcss-hashes.nix:"
echo "  \"$VERSION\" = {"
echo "    npmDeps = {"
echo "      \"$SYSTEM\" = \"$HASH\";"
echo "    };"
echo "  };"
