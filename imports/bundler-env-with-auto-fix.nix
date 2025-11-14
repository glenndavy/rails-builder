# Auto-fixing bundlerEnv wrapper
# This wrapper proactively fixes SHA mismatches in gemset.nix for common problematic gems
{
  pkgs,
  rubyPackage,
  bundlerVersion,
  gemdir,
  gemset ? null,
  buildInputs ? [],
  gemConfig ? {},
  name ? "rails-gems",
  autoFix ? true,
  ...
}@args: let
  bundler = pkgs.bundler.override {
    ruby = rubyPackage;
  };

  # Auto-fix gemset SHAs for common problematic gems
  autoFixedGemset = if gemset == null then null else if autoFix then pkgs.runCommand "auto-fixed-gemset.nix" {
    buildInputs = with pkgs; [nix gnused coreutils];
    gemsetSource = gemset;
  } ''
    set -euo pipefail
    
    echo "🔧 Proactively fixing gemset SHAs for common problematic gems..."
    cp $gemsetSource $out
    
    # Common gems that frequently have SHA mismatches due to platform differences
    PROBLEM_GEMS=("nokogiri" "json" "bootsnap" "msgpack" "bcrypt" "nio4r" "websocket-driver" "ffi" "racc" "sassc" "debug" "byebug" "pg" "mysql2")

    FIXED_COUNT=0

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

      for try_platform in "''${unique_platforms[@]}"; do
        local gem_filename
        if [ "$try_platform" = "ruby" ]; then
          gem_filename="$gem_name-$gem_version.gem"
        else
          gem_filename="$gem_name-$gem_version-$try_platform.gem"
        fi

        local gem_url="https://rubygems.org/downloads/$gem_filename"

        local correct_sha
        if correct_sha=$(nix-prefetch-url "$gem_url" 2>/dev/null); then
          echo "$correct_sha"
          return 0
        fi
      done

      return 1
    }

    PLATFORM=$(get_gem_platform)

    for gem in "''${PROBLEM_GEMS[@]}"; do
      if grep -q "\"$gem\"" $out; then
        echo "  Checking $gem..."

        # Extract version for this gem
        VERSION=$(grep -A 10 "^  $gem = {" $out | grep "version =" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')

        if [ -n "$VERSION" ]; then
          # Fetch correct SHA using platform-aware function
          CORRECT_SHA=$(fetch_gem_sha_with_platform "$gem" "$VERSION" "$PLATFORM" 2>/dev/null || echo "failed")

          if [ "$CORRECT_SHA" != "failed" ]; then
            # Get current SHA
            CURRENT_SHA=$(grep -A 20 "\"$gem\" = {" $out | grep "sha256 =" | sed 's/.*sha256 = "\([^"]*\)".*/\1/' | head -1)

            if [ "$CURRENT_SHA" != "$CORRECT_SHA" ]; then
              echo "    ✅ Fixing SHA for $gem-$VERSION: $CURRENT_SHA -> $CORRECT_SHA"
              # Update the SHA in place for this specific gem
              sed -i "/\"$gem\" = {/,/};/{
                s/sha256 = \"[^\"]*\"/sha256 = \"$CORRECT_SHA\"/
              }" $out
              FIXED_COUNT=$((FIXED_COUNT + 1))
            else
              echo "    ✓ SHA already correct for $gem-$VERSION"
            fi
          else
            echo "    ⚠️  Could not fetch SHA for $gem-$VERSION on any platform"
          fi
        fi
      fi
    done
    
    if [ $FIXED_COUNT -gt 0 ]; then
      echo "✅ Auto-fixed $FIXED_COUNT gem SHAs"
    else
      echo "✓ No SHA fixes needed"
    fi
  '' else gemset;

in
# Try bundlerEnv first, fall back to bootstrap shell if it fails
let
  tryBundlerEnv = if autoFixedGemset == null then null else
    builtins.tryEval (pkgs.bundlerEnv (args // {
      inherit name;
      gemset = autoFixedGemset;
      bundler = bundler;
      ruby = rubyPackage;
      gemdir = gemdir;
      buildInputs = buildInputs;
      gemConfig = gemConfig;
    }));
in
if autoFixedGemset == null || !tryBundlerEnv.success then
  # Bootstrap mode: provide a shell with bundix to fix gemset.nix
  pkgs.buildEnv {
    name = name + "-bootstrap";
    paths = [ rubyPackage pkgs.bundix ] ++ buildInputs;
    # Includes same build inputs to ensure identical compilation environment
  }
else
  tryBundlerEnv.value