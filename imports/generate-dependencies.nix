{
  pkgs,
  rubyPackage,
  bundlerVersion,
  bundixPackage,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "Generating gemset.nix from Gemfile.lock..."
  export PATH=${rubyPackage}/bin:${pkgs.nix-prefetch-scripts}/bin:${bundixPackage}/bin:$PATH
  echo "Verifying Ruby version: $(${rubyPackage}/bin/ruby -v)"
  export GEM_HOME=$(mktemp -d)
  ${rubyPackage}/bin/gem install bundler --version ${bundlerVersion} --no-document
  export PATH=$GEM_HOME/bin:$PATH
  bundix -l

  # If vendor/cache exists, fix SHAs from vendored gems automatically
  if [ -d "vendor/cache" ]; then
    echo "📦 Found vendor/cache - fixing SHAs from vendored gems..."

    # Common gems that often have SHA mismatches
    PROBLEM_GEMS="nokogiri json bootsnap msgpack bcrypt nio4r websocket-driver ffi racc sassc pg mysql2"

    for gem in $PROBLEM_GEMS; do
      if grep -q "\"$gem\"" gemset.nix; then
        VERSION=$(grep -A 10 "^  $gem = {" gemset.nix | grep "version =" | head -1 | sed 's/.*version = "\([^"]*\)".*/\1/')

        if [ -n "$VERSION" ]; then
          # Try to find vendored gem (platform-specific or generic)
          VENDORED_GEM=""
          for gem_file in vendor/cache/$gem-$VERSION*.gem; do
            if [ -f "$gem_file" ]; then
              VENDORED_GEM="$gem_file"
              break
            fi
          done

          if [ -n "$VENDORED_GEM" ]; then
            CORRECT_SHA=$(${pkgs.nix}/bin/nix hash file "$VENDORED_GEM" 2>/dev/null || echo "")
            if [ -n "$CORRECT_SHA" ]; then
              echo "  ✅ Fixing $gem-$VERSION from vendored gem"
              # Use | as delimiter instead of / to avoid conflicts with base64 chars
              ${pkgs.gnused}/bin/sed -i "/\"$gem\" = {/,/};/s|sha256 = \"[^\"]*\"|sha256 = \"$CORRECT_SHA\"|" gemset.nix
            fi
          fi
        fi
      fi
    done

    echo "✅ SHAs fixed from vendored gems"
  fi
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock | grep sha256 | cut -d '"' -f2)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
  fi
  git add gemset.nix
  echo "Done."
''
