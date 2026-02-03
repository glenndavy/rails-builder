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

  # Fix git gem entries that bundix couldn't fetch from remote repositories
  # When bundix can't access a private git repo (e.g., no SSH in CI), it creates
  # gemset.nix entries without source/version attributes. If the gem is vendored
  # in vendor/cache, we patch the entry to use a local path source instead.
  if [ -d "vendor/cache" ] && [ -f "Gemfile.lock" ] && [ -f "gemset.nix" ]; then
    echo "🔧 Checking for vendor/cache git gems that need gemset.nix patching..."

    for cached_gem_dir in vendor/cache/*; do
      if [ -d "$cached_gem_dir" ] && [ -f "$cached_gem_dir/.bundlecache" ]; then
        gem_dir_name=$(basename "$cached_gem_dir")

        # Extract gem name: remove trailing hex hash
        # e.g., opscare-reports-6eed40cd3717 -> opscare-reports
        gem_name_hyphen=$(echo "$gem_dir_name" | ${pkgs.gnused}/bin/sed 's/-[a-f0-9]\{7,\}$//')
        # Convert to underscored name as used in gemset.nix
        # e.g., opscare-reports -> opscare_reports
        gem_name=$(echo "$gem_name_hyphen" | tr '-' '_')

        # Check if this gem exists in gemset.nix but is missing source attribute
        has_source=$(${pkgs.gawk}/bin/awk '
          /^  '"$gem_name"' = \{/ { in_block=1; next }
          in_block && /^  \};/ { exit }
          in_block && /source = \{/ { print "yes"; exit }
        ' gemset.nix)

        if [ "$has_source" != "yes" ] && grep -q "  $gem_name = {" gemset.nix; then
          # Extract version from Gemfile.lock GIT specs section
          version=$(${pkgs.gawk}/bin/awk '
            /^GIT/ { in_git=1; next }
            /^[A-Z]/ && !/^GIT/ { in_git=0 }
            in_git && /specs:/ { in_specs=1; next }
            in_git && in_specs && /'"$gem_name"' \(/ {
              gsub(/.*\(/, ""); gsub(/\).*/, ""); print; exit
            }
          ' Gemfile.lock)

          if [ -n "$version" ]; then
            echo "  🔧 Patching $gem_name: adding source (path: ./$cached_gem_dir) and version ($version)"

            # Inject source and version before the closing }; of this gem's block
            ${pkgs.gawk}/bin/awk -v gem_name="$gem_name" -v gem_path="./$cached_gem_dir" -v ver="$version" '
              $0 ~ "^  " gem_name " = \\{" { in_block=1 }
              in_block && /^  };/ {
                print "    source = {"
                print "      path = \"" gem_path "\";"
                print "      type = \"path\";"
                print "    };"
                print "    version = \"" ver "\";"
                in_block=0
              }
              { print }
            ' gemset.nix > gemset.nix.tmp && mv gemset.nix.tmp gemset.nix

            echo "  ✅ Patched $gem_name in gemset.nix"
          else
            echo "  ⚠️ Could not determine version for $gem_name from Gemfile.lock - skipping"
          fi
        fi
      fi
    done
  fi

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
