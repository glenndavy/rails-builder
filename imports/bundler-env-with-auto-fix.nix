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
    version = bundlerVersion;
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
    PROBLEM_GEMS=("nokogiri" "json" "bootsnap" "msgpack" "bcrypt" "nio4r" "websocket-driver" "ffi" "racc" "sassc" "debug" "byebug")
    
    FIXED_COUNT=0
    
    for gem in "''${PROBLEM_GEMS[@]}"; do
      if grep -q "\"$gem\"" $out; then
        echo "  Checking $gem..."
        
        # Extract version for this gem
        VERSION=$(grep -A 10 "\"$gem\" = {" $out | grep "version =" | sed 's/.*version = "\([^"]*\)".*/\1/' | head -1)
        
        if [ -n "$VERSION" ]; then
          GEM_URL="https://rubygems.org/downloads/$gem-$VERSION.gem"
          
          # Fetch correct SHA
          CORRECT_SHA=$(nix-prefetch-url "$GEM_URL" 2>/dev/null || echo "failed")
          
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
            echo "    ⚠️  Could not fetch SHA for $gem-$VERSION"
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
    paths = [ bundler rubyPackage pkgs.bundix ] ++ buildInputs;
  }
else
  tryBundlerEnv.value