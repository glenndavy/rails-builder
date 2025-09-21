{pkgs}: ''
  #!/usr/bin/env bash
  set -euo pipefail

  echo "🔧 Fixing SHA mismatches in gemset.nix..."
  echo "Arguments received: $#: $@"

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

  # If we have a gem name as argument, fix that specific gem
  if [ $# -gt 0 ]; then
    if [[ "$1" == *"hash mismatch"* ]]; then
      # Parse error output
      fix_sha_from_error "$1"
      exit $?
    else
      # Treat as gem name directly
      gem_name="$1"
      gem_version=""
      if [ $# -gt 1 ]; then
        gem_version="$2"
      else
        # Extract version from gemset.nix
        gem_version=$(grep -A 10 "\"$gem_name\"" gemset.nix | grep "version =" | sed 's/.*version = "\([^"]*\)".*/\1/')
      fi

      if [ -z "$gem_version" ]; then
        echo "❌ Could not determine version for gem: $gem_name"
        echo "💡 Usage: fix-gemset-sha [gem-name] [version]"
        echo "💡    or: fix-gemset-sha 'error line with hash mismatch'"
        exit 1
      fi

      echo "🔍 Fixing SHA for $gem_name-$gem_version..."
      gem_url="https://rubygems.org/downloads/$gem_name-$gem_version.gem"
      echo "📥 Fetching correct SHA from: $gem_url"

      correct_sha=""
      if correct_sha=$(${pkgs.nix}/bin/nix-prefetch-url "$gem_url" 2>/dev/null); then
        echo "✅ Correct SHA: $correct_sha"

        # Update gemset.nix with correct SHA
        ${pkgs.gnused}/bin/sed -i.bak \
          "/\"$gem_name\" = {/,/};/ s/sha256 = \"[^\"]*\"/sha256 = \"$correct_sha\"/" \
          gemset.nix

        echo "✅ Updated $gem_name SHA in gemset.nix"
        echo "📦 Backup saved as gemset.nix.bak"
        exit 0
      else
        echo "❌ Failed to fetch correct SHA for $gem_name-$gem_version"
        exit 1
      fi
    fi
    exit $?
  fi

  # Otherwise, try building dev environment and fix any SHA errors
  echo "🧪 Testing by building dev environment..."

  temp_result=$(mktemp)
  echo "🔄 Running 'nix develop .#dev --command echo test' to trigger gem builds..."
  echo "Running dev environment test..." >> "$DEBUG_LOG"
  if nix develop .#dev --command echo "test" 2> "$temp_result" >/dev/null; then
    echo "✅ All gem SHAs are correct!"
    echo "Dev environment succeeded" >> "$DEBUG_LOG"
    rm -f "$temp_result"
  else
    echo "🔧 Found SHA mismatches, attempting to fix..."
    echo "Dev environment failed, error output:" >> "$DEBUG_LOG"
    cat "$temp_result" >> "$DEBUG_LOG"

    while read -r line; do
      echo "Processing line: $line" >> "$DEBUG_LOG"
      if [[ "$line" == *"hash mismatch in fixed-output derivation"* ]]; then
        echo "Found hash mismatch line: $line" >> "$DEBUG_LOG"
        if fix_sha_from_error "$line"; then
          echo "🔄 Retesting dev environment after SHA fix..."
          # Retry the dev environment
          if nix develop .#dev --command echo "test" 2>/dev/null >/dev/null; then
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