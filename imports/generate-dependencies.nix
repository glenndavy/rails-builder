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

  # If vendor/cache exists, rewrite gemset entries for problem gems to use the
  # vendored .gem file directly as their source. This makes the build hermetic
  # from vendor/cache (no rubygems.org fetch at build time) and removes the
  # whole class of SHA mismatches between bundix-resolved and bundle-packaged
  # gem variants.
  if [ -d "vendor/cache" ]; then
    echo "📦 Found vendor/cache - rewriting gemset to source from vendored .gem files..."

    # Platform candidates — tried in order as fallback when no source-variant
    # .gem is vendored. Newer Linux gems use the explicit "<arch>-linux-gnu"
    # platform tag; older ones use just "<arch>-linux". List both so either
    # vendored variant gets picked up.
    PLATFORM_CANDIDATES=()
    case "$(uname -s)" in
      Linux)
        case "$(uname -m)" in
          x86_64)  PLATFORM_CANDIDATES=("x86_64-linux-gnu" "x86_64-linux") ;;
          aarch64) PLATFORM_CANDIDATES=("aarch64-linux-gnu" "aarch64-linux") ;;
        esac
        ;;
      Darwin)
        case "$(uname -m)" in
          x86_64) PLATFORM_CANDIDATES=("x86_64-darwin") ;;
          arm64)  PLATFORM_CANDIDATES=("arm64-darwin") ;;
        esac
        ;;
    esac

    # Every gem in gemset.nix — if any has a matching vendored .gem, rewrite
    # its source to point at it. Avoids a hardcoded safelist and catches every
    # gem whose bundix-resolved SHA might disagree with what was bundle-packaged
    # (typically gems with precompiled platform variants).
    ALL_GEMS=$(${pkgs.gnugrep}/bin/grep -E '^  [a-zA-Z_][a-zA-Z0-9_-]* = \{' gemset.nix | ${pkgs.gnused}/bin/sed 's/^  //;s/ = {.*//')

    for gem in $ALL_GEMS; do
      VERSION=$(${pkgs.gawk}/bin/awk -v g="$gem" '
        $0 ~ "^  " g " = \\{" { in_block=1; next }
        in_block && /^  \};$/ { exit }
        in_block && /version = / {
          gsub(/.*version = "/, "")
          gsub(/".*/, "")
          print
          exit
        }
      ' gemset.nix)

      if [ -z "$VERSION" ]; then continue; fi

      # Prefer source variant (no platform suffix) so Nix compiles against its
      # own libs; fall back to a precompiled .gem matching the current platform.
      VENDORED_GEM=""
      if [ -f "vendor/cache/$gem-$VERSION.gem" ]; then
        VENDORED_GEM="vendor/cache/$gem-$VERSION.gem"
      else
        for plat in "''${PLATFORM_CANDIDATES[@]}"; do
          if [ -f "vendor/cache/$gem-$VERSION-$plat.gem" ]; then
            VENDORED_GEM="vendor/cache/$gem-$VERSION-$plat.gem"
            break
          fi
        done
      fi

      if [ -z "$VENDORED_GEM" ]; then
        continue
      fi

      echo "  ✅ Pointing $gem-$VERSION source at $VENDORED_GEM"

      ${pkgs.gawk}/bin/awk -v g="$gem" -v p="./$VENDORED_GEM" '
        $0 ~ "^  " g " = \\{" { in_block=1; print; next }
        in_block && /^  \};$/ { in_block=0; in_source=0; print; next }
        in_block && !in_source && /source = \{/ {
          print "    source = {"
          print "      path = \"" p "\";"
          print "      type = \"gem\";"
          print "    };"
          in_source=1
          next
        }
        in_source && /^    \};$/ { in_source=0; next }
        in_source { next }
        { print }
      ' gemset.nix > gemset.nix.tmp && mv gemset.nix.tmp gemset.nix
    done

    echo "✅ Vendored gem rewrites complete"
  fi
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash (fetchYarnDeps fallback path)..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock | grep sha256 | cut -d '"' -f2)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
  fi

  # Generate bun-built node_modules hash if the app has JS deps. Writes
  # `.bun-deps.sha` next to the lockfile — make-rails-nix-build.nix reads
  # this automatically (no flake.nix edit required). Mirrors the FOD recipe
  # in make-rails-nix-build.nix so the computed hash matches what nix-build
  # produces.
  if [ -f package.json ] || [ -f yarn.lock ]; then
    echo "🧩 Computing bun-built node_modules hash (.bun-deps.sha)..."
    bun_build=$(${pkgs.coreutils}/bin/mktemp -d)
    cp package.json "$bun_build/"
    [ -f yarn.lock ] && cp yarn.lock "$bun_build/"
    (cd "$bun_build" && ${pkgs.bun}/bin/bun install --production --no-progress 2>&1 | tail -3)
    bun_out=$(${pkgs.coreutils}/bin/mktemp -d)
    cp -r "$bun_build/node_modules" "$bun_out/"
    bun_hash=$(${pkgs.nix}/bin/nix hash path --type sha256 --sri "$bun_out")
    echo "$bun_hash" > .bun-deps.sha
    echo "  ✅ Written .bun-deps.sha = $bun_hash"
    rm -rf "$bun_build" "$bun_out"
    ${pkgs.git}/bin/git add .bun-deps.sha 2>/dev/null || true
  fi

  ${pkgs.git}/bin/git add gemset.nix 2>/dev/null || true
  echo "Done."
''
