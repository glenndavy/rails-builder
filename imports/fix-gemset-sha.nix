{pkgs}: ''
  #!/usr/bin/env bash
  set -euo pipefail

  echo "🔧 Fixing SHA mismatches in gemset.nix..."
  echo "Arguments received: $#: $@"

  if [ ! -f "gemset.nix" ]; then
    echo "❌ No gemset.nix found. Run 'bundix' first to generate it."
    exit 1
  fi

  # Function to add dontBuild = false to gems with native extensions
  fix_native_extensions() {
    echo "🔧 Adding dontBuild = false to gems with native extensions..."
    local gems_with_extensions=("json" "bootsnap" "msgpack" "nokogiri" "bcrypt" "nio4r" "websocket-driver" "ffi" "racc" "sassc" "debug" "byebug")

    for gem in "''${gems_with_extensions[@]}"; do
      if grep -q "^  $gem = {" gemset.nix; then
        if ! grep -A 20 "^  $gem = {" gemset.nix | grep -q "dontBuild"; then
          echo "  Adding dontBuild = false to $gem..."
          # Find the closing brace for this gem and add dontBuild before it
          sed -i.bak "/^  $gem = {/,/^  };/{
            s/^  };$/    dontBuild = false;  # Ensure native extensions are built\n  };/
          }" gemset.nix
        fi
      fi
    done
  }


  # Function to detect current platform for platform-specific gems
  get_gem_platform() {
    local arch=$(uname -m)
    local os=$(uname -s)

    case "$os" in
      Linux)
        case "$arch" in
          x86_64) echo "x86_64-linux-gnu" ;;
          aarch64) echo "aarch64-linux-gnu" ;;
          arm*) echo "arm-linux-gnu" ;;
          *) echo "ruby" ;;  # fallback to ruby platform
        esac
        ;;
      Darwin)
        case "$arch" in
          x86_64) echo "x86_64-darwin" ;;
          arm64) echo "arm64-darwin" ;;
          *) echo "ruby" ;;  # fallback to ruby platform
        esac
        ;;
      *)
        echo "ruby"  # fallback to ruby platform for unknown OS
        ;;
    esac
  }

  # Function to try fetching gem SHA with platform variants
  fetch_gem_sha_with_platform() {
    local gem_name="$1"
    local gem_version="$2"
    local platform="$3"

    # List of platforms to try in order of preference
    local platforms_to_try=()

    # Add current platform first if it's not ruby
    if [ "$platform" != "ruby" ]; then
      platforms_to_try+=("$platform")
    fi

    # Add common platform variants for problematic gems
    case "$gem_name" in
      nokogiri|json|bootsnap|msgpack|bcrypt|nio4r|websocket-driver|ffi|racc|sassc|debug|byebug|pg|mysql2)
        case "$(uname -s)" in
          Linux)
            platforms_to_try+=("x86_64-linux-gnu" "aarch64-linux-gnu" "x86_64-linux-musl" "aarch64-linux-musl")
            ;;
          Darwin)
            platforms_to_try+=("x86_64-darwin" "arm64-darwin")
            ;;
        esac
        ;;
    esac

    # Always try ruby platform last as fallback
    platforms_to_try+=("ruby")

    # Remove duplicates while preserving order
    local unique_platforms=()
    for plat in "''${platforms_to_try[@]}"; do
      if [[ ! " ''${unique_platforms[*]} " =~ " $plat " ]]; then
        unique_platforms+=("$plat")
      fi
    done

    echo "🔍 Trying platforms for $gem_name-$gem_version: ''${unique_platforms[*]}"

    # FIRST: Check vendor/cache for vendored gems (from bundle package)
    if [ -d "vendor/cache" ]; then
      echo "📦 Checking vendor/cache for vendored gems..."
      for try_platform in "''${unique_platforms[@]}"; do
        local gem_filename
        if [ "$try_platform" = "ruby" ]; then
          gem_filename="$gem_name-$gem_version.gem"
        else
          gem_filename="$gem_name-$gem_version-$try_platform.gem"
        fi

        local vendored_gem="vendor/cache/$gem_filename"
        if [ -f "$vendored_gem" ]; then
          echo "  ✅ Found vendored gem: $vendored_gem"
          local correct_sha
          if correct_sha=$(${pkgs.nix}/bin/nix hash file "$vendored_gem" 2>/dev/null); then
            echo "  ✅ SUCCESS with vendored gem (platform '$try_platform'): $correct_sha"
            echo "$correct_sha"
            return 0
          fi
        fi
      done
      echo "  ⚠️  No matching vendored gem found, falling back to rubygems.org..."
    fi

    # FALLBACK: Fetch from rubygems.org
    for try_platform in "''${unique_platforms[@]}"; do
      local gem_filename
      if [ "$try_platform" = "ruby" ]; then
        gem_filename="$gem_name-$gem_version.gem"
      else
        gem_filename="$gem_name-$gem_version-$try_platform.gem"
      fi

      local gem_url="https://rubygems.org/downloads/$gem_filename"
      echo "📥 Trying: $gem_url"

      local correct_sha
      if correct_sha=$(${pkgs.nix}/bin/nix-prefetch-url "$gem_url" 2>/dev/null); then
        echo "✅ SUCCESS with platform '$try_platform': $correct_sha"
        echo "$correct_sha"
        return 0
      else
        echo "   ❌ Failed for platform '$try_platform'"
      fi
    done

    echo "❌ Failed to fetch SHA for $gem_name-$gem_version on any platform"
    return 1
  }

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

    local platform=$(get_gem_platform)
    echo "🖥️  Detected platform: $platform"

    local correct_sha
    if correct_sha=$(fetch_gem_sha_with_platform "$gem_name" "$gem_version" "$platform"); then
      # Update gemset.nix with correct SHA
      ${pkgs.gnused}/bin/sed -i.bak \
        "/\"$gem_name\" = {/,/};/ s/sha256 = \"[^\"]*\"/sha256 = \"$correct_sha\"/" \
        gemset.nix

      echo "✅ Updated $gem_name SHA in gemset.nix"
      return 0
    else
      echo "❌ Failed to fetch correct SHA for $gem_name-$gem_version on any platform"
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
        gem_version=$(grep -A 10 "^  $gem_name = {" gemset.nix | grep "version =" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')
      fi

      if [ -z "$gem_version" ]; then
        echo "❌ Could not determine version for gem: $gem_name"
        echo "💡 Usage: fix-gemset-sha [gem-name] [version]"
        echo "💡    or: fix-gemset-sha 'error line with hash mismatch'"
        exit 1
      fi

      echo "🔍 Fixing SHA for $gem_name-$gem_version..."

      local platform=$(get_gem_platform)
      echo "🖥️  Detected platform: $platform"

      correct_sha=""
      if correct_sha=$(fetch_gem_sha_with_platform "$gem_name" "$gem_version" "$platform"); then
        # Update gemset.nix with correct SHA
        ${pkgs.gnused}/bin/sed -i.bak \
          "/\"$gem_name\" = {/,/};/ s/sha256 = \"[^\"]*\"/sha256 = \"$correct_sha\"/" \
          gemset.nix

        echo "✅ Updated $gem_name SHA in gemset.nix"
        echo "📦 Backup saved as gemset.nix.bak"
        exit 0
      else
        echo "❌ Failed to fetch correct SHA for $gem_name-$gem_version on any platform"
        exit 1
      fi
    fi
    exit $?
  fi

  # Fix native extensions first
  fix_native_extensions

  # Otherwise, try building dev environment and fix any SHA errors
  DEBUG_LOG="/tmp/fix-gemset-debug.log"
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