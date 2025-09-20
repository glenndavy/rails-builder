{pkgs}: ''
  #!/usr/bin/env bash
  set -euo pipefail

  echo "🔧 Fixing SHA mismatches in gemset.nix..."

  if [ ! -f "gemset.nix" ]; then
    echo "❌ No gemset.nix found. Run 'bundix' first to generate it."
    exit 1
  fi

  # Function to extract gem name and incorrect SHA from nix error
  fix_sha_from_error() {
    local error_output="$1"

    # Extract derivation path that contains gem name and version
    local drv_path=$(echo "$error_output" | grep -o "'/nix/store/[^']*\.gem\.drv'" | head -1 | tr -d "'")

    if [ -z "$drv_path" ]; then
      echo "❌ Could not extract gem information from error"
      return 1
    fi

    # Extract gem name and version from derivation name
    local gem_file=$(basename "$drv_path" .drv)
    local gem_name=$(echo "$gem_file" | sed 's/-[0-9].*//')
    local gem_version=$(echo "$gem_file" | sed "s/$gem_name-//" | sed 's/\.gem$//')

    echo "🔍 Fixing SHA for $gem_name-$gem_version..."

    # Get the correct SHA using nix-prefetch-url
    local gem_url="https://rubygems.org/downloads/$gem_name-$gem_version.gem"
    echo "📥 Fetching correct SHA from: $gem_url"

    local correct_sha
    if correct_sha=$(${pkgs.nix}/bin/nix-prefetch-url "$gem_url" 2>/dev/null); then
      echo "✅ Correct SHA: $correct_sha"

      # Update gemset.nix with correct SHA
      ${pkgs.gnused}/bin/sed -i.bak \
        "/\"$gem_name\" = {/,/};/ s/sha256 = \"[^\"]*\"/sha256 = \"$correct_sha\"/" \
        gemset.nix

      echo "✅ Updated $gem_name SHA in gemset.nix"
      return 0
    else
      echo "❌ Failed to fetch correct SHA for $gem_name-$gem_version"
      return 1
    fi
  }

  # If we have error output as argument, fix specific gem
  if [ $# -gt 0 ]; then
    fix_sha_from_error "$1"
    exit $?
  fi

  # Otherwise, try building and fix any SHA errors interactively
  echo "🧪 Testing gemset.nix by building gems..."

  temp_result=$(mktemp)
  if nix build --no-link --expr "
    let
      pkgs = import <nixpkgs> {};
      gemset = import ./gemset.nix;
    in
      pkgs.lib.mapAttrs (name: gemAttrs: pkgs.fetchurl {
        url = \"https://rubygems.org/downloads/\" + name + \"-\" + gemAttrs.version + \".gem\";
        inherit (gemAttrs.source) sha256;
      }) gemset
  " 2> "$temp_result"; then
    echo "✅ All gem SHAs are correct!"
    rm -f "$temp_result"
  else
    echo "🔧 Found SHA mismatches, attempting to fix..."

    while read -r line; do
      if [[ "$line" == *"hash mismatch in fixed-output derivation"* ]]; then
        if fix_sha_from_error "$line"; then
          echo "🔄 Retrying build after SHA fix..."
          # Retry the build
          if nix build --no-link --expr "
            let
              pkgs = import <nixpkgs> {};
              gemset = import ./gemset.nix;
            in
              pkgs.lib.mapAttrs (name: gemAttrs: pkgs.fetchurl {
                url = \"https://rubygems.org/downloads/\${name}-\${gemAttrs.version}.gem\";
                inherit (gemAttrs.source) sha256;
              }) gemset
          " 2>/dev/null; then
            echo "✅ SHA fix successful!"
          else
            echo "⚠️  Still have issues, may need manual intervention"
          fi
        fi
      fi
    done < "$temp_result"

    rm -f "$temp_result"
  fi

  echo "🎉 Gemset SHA verification complete!"
  echo ""
  echo "💡 Usage tips:"
  echo "   - Run this script after 'bundix' if you get SHA errors"
  echo "   - Or pipe nix error output: nix build 2>&1 | fix-gemset-sha"
  echo "   - Backup gemset.nix.bak is created automatically"
''