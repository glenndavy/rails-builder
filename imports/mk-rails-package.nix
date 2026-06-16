# imports/mk-rails-package.nix
#
# Helper function to build Rails applications with all correct configuration.
# Use this from external flakes instead of calling make-rails-nix-build.nix directly.
#
# This ensures:
#   - customBundlerEnv is used (handles vendor/cache path gems correctly)
#   - tailwindcssPackage is included (for Tailwind CSS v4 support)
#   - bundlerPackage matches Gemfile.lock version
#   - gemConfig includes ruby-vips and other gem-specific fixes
#
# Usage in your flake (local gemset.nix in app source):
#
#   let
#     railsBuild = rails-builder.lib.${system}.mkRailsPackage {
#       inherit pkgs;
#       src = rails-app-src;
#       # Optional overrides:
#       # appName = "my-app";
#       # railsEnv = "production";  # default, or "staging", "test"
#       # rubyVersion = "3.2.0";  # auto-detected from .ruby-version if not specified
#     };
#   in {
#     packages.rails-app = railsBuild.app;
#     packages.docker-image = railsBuild.dockerImage;
#     packages.gems = railsBuild.gems;
#   }
#
# Usage with external gemset.nix (orchestrator pattern):
#
#   let
#     railsBuild = rails-builder.lib.${system}.mkRailsPackage {
#       inherit pkgs;
#       src = my-rails-app-input;           # App source (no flake.nix needed)
#       gemset = ./apps/my-app/gemset.nix;  # gemset.nix in orchestrator repo
#       appName = "my-app";
#     };
#   in { ... }
#
{
  pkgs,
  src,            # Path to the Rails application source
  appName ? null, # Optional: Custom app name (defaults to "rails-app")
  gemset ? null,  # Optional: Path to gemset.nix (defaults to src + "/gemset.nix")
  railsEnv ? "production", # Rails environment for asset precompilation
  rubyVersion ? null,     # Optional: Override Ruby version (auto-detected from .ruby-version)
  bundlerVersion ? null,  # Optional: Override Bundler version (auto-detected from Gemfile.lock)
  opensslVersion ? "3_2", # OpenSSL version: "3_2" (default) or "1_1" for legacy
  gccVersion ? "latest",  # GCC version
  extraBuildInputs ? [],  # Additional build inputs
  extraGemConfig ? {},    # Additional gem configuration
  appRevision ? null,     # Optional: Git revision (falls back to src.rev / src.dirtyRev)
  yarnDepsHash ? null,    # Optional: SHA256 of fetchYarnDeps output (required if app has yarn.lock)
                          #   Compute with: prefetch-yarn-deps yarn.lock
                          #   Or set to lib.fakeHash and read the correct hash off the build error.
                          #   Has gaps for git URLs / scoped / aliased deps — see bunDepsHash.
  bunDepsHash ? null,     # Optional: SHA256 of bun-installed node_modules (preferred when fetchYarnDeps
                          #   can't handle your lockfile — git URLs, scoped registries, aliased deps).
                          #   First run: pass pkgs.lib.fakeHash and copy the `got:` line.
                          #   Takes precedence over yarnDepsHash when both are set.
  nixpkgsRubyOverlay ? null, # Internal: nixpkgs-ruby overlay (passed by rails-builder)
  railsBuilderVersion ? "unknown", # Internal: version for debugging (passed by rails-builder)
}:
let
  system = pkgs.system;

  # Apply nixpkgs-ruby overlay to get ruby-X.Y.Z packages
  # This is passed automatically by rails-builder.lib.mkRailsPackage
  pkgsWithRuby = if nixpkgsRubyOverlay != null
    then pkgs.extend nixpkgsRubyOverlay
    else pkgs;

  # Import detection utilities
  versionDetection = import ./detect-versions.nix;
  detectFramework = import ./detect-framework.nix;

  # Detect versions from source (or use overrides)
  detectedRubyVersion =
    if rubyVersion != null
    then rubyVersion
    else versionDetection.detectRubyVersion { inherit src; };

  detectedBundlerVersion =
    if bundlerVersion != null
    then bundlerVersion
    else versionDetection.detectBundlerVersion { inherit src; };

  detectedTailwindVersion = versionDetection.detectTailwindVersion { inherit src; };

  # Detect git revision from source tree (for path: inputs that include .git)
  resolvedAppRevision = let
    gitHeadFile = src + "/.git/HEAD";
    hasGitHead = builtins.pathExists gitHeadFile;
    headContent =
      if hasGitHead
      then builtins.replaceStrings ["\n" "\r"] ["" ""] (builtins.readFile gitHeadFile)
      else null;
    # Detached HEAD: file contains raw 40-char hex SHA
    isDetachedHead = headContent != null
      && builtins.match "[0-9a-f]{40}" headContent != null;
    # Branch ref: file contains "ref: refs/heads/..."
    isRef = headContent != null
      && builtins.substring 0 5 headContent == "ref: ";
    refRelPath =
      if isRef
      then builtins.substring 5 (builtins.stringLength headContent - 5) headContent
      else null;
    refFile =
      if refRelPath != null
      then src + "/.git/${refRelPath}"
      else null;
    refContent =
      if refFile != null && builtins.pathExists refFile
      then builtins.replaceStrings ["\n" "\r"] ["" ""] (builtins.readFile refFile)
      else null;
  in
    if appRevision != null then appRevision
    else if src ? rev then src.rev
    else if src ? dirtyRev then builtins.replaceStrings ["-dirty"] [""] src.dirtyRev
    else if isDetachedHead then headContent
    else if refContent != null then refContent
    else null;

  # Framework detection
  frameworkInfo = detectFramework { inherit src; };
  framework = frameworkInfo.framework;

  # Ruby package (from nixpkgs-ruby overlay)
  rubyPackage = pkgsWithRuby."ruby-${detectedRubyVersion}";
  rubyVersionSplit = builtins.splitVersion detectedRubyVersion;
  rubyMajorMinor = "${builtins.elemAt rubyVersionSplit 0}.${builtins.elemAt rubyVersionSplit 1}";

  # OpenSSL and GCC packages
  opensslPackage =
    if opensslVersion == "3_2"
    then pkgs.openssl_3
    else pkgs."openssl_${opensslVersion}";

  gccPackage =
    if gccVersion == "latest"
    then pkgs.gcc
    else pkgs."gcc${gccVersion}";

  # Bundler package — extracted to imports/make-bundler-package.nix so the
  # template and mk-rails-package share one implementation.
  bundlerPackage = import ./make-bundler-package.nix {
    inherit pkgs;
    ruby = rubyPackage;
    version = detectedBundlerVersion;
  };

  # Tailwindcss package (if needed)
  tailwindcssHashes = import ../tailwindcss-hashes.nix;
  tailwindcssPackage =
    if detectedTailwindVersion != null && frameworkInfo.needsTailwindcss
    then
      import ./make-tailwindcss.nix {
        inherit pkgs tailwindcssHashes;
        version = detectedTailwindVersion;
        lockfilesPath = ../tailwindcss-locks;
      }
    else null;

  # Yarn offline cache. If the app has a yarn.lock, make-rails-nix-build.nix
  # runs `yarn install --offline`, which fails unless the cache is populated
  # with every tarball the lockfile references. fetchYarnDeps does the
  # populate step, but as a fixed-output derivation it needs the SHA256 of
  # the produced cache declared up-front.
  #
  # Caller workflow:
  #   1. First build: leave yarnDepsHash unset and read the error — the
  #      build will fail with "do not know how to unpack" or similar before
  #      we get here. Alternatively pass pkgs.lib.fakeHash to get a clean
  #      hash-mismatch error directly from fetchYarnDeps.
  #   2. Copy the `got:` SHA from the error into yarnDepsHash.
  # JS deps (bunDepsHash / yarnDepsHash) are passed through to
  # make-rails-nix-build.nix, which handles fetching and the precedence
  # rules. Keeping the logic in one place avoids drift between this helper,
  # the universal template, and direct callers.

  # Use customBundlerEnv from rails-builder (handles vendor/cache path gems)
  # Must use callPackage to provide lib, callPackage, defaultGemConfig, etc.
  # Pass our version-matched bundlerPackage in so customBundlerEnv's fallback
  # (when gemset.nix doesn't include `bundler`) doesn't pull nixpkgs's
  # current bundler — which may be too new for older Rubies. For Ruby <3.0
  # apps, nixpkgs bundler 2.7+ uses Module#method_defined?(name, inherit)
  # and crashes the bin/rails invocation at require-time. Same issue as
  # bundix #1, different consumer.
  customBundlerEnv = pkgs.callPackage ./bundler-env { bundler = bundlerPackage; };

  # Check if gemset.nix exists - either explicitly provided or in src
  # Priority: explicit gemset parameter > src + "/gemset.nix"
  hasGemset =
    if gemset != null
    then true
    else builtins.pathExists (src + "/gemset.nix");

  # Resolve which gemset.nix to use
  resolvedGemset =
    if gemset != null
    then gemset
    else src + "/gemset.nix";

  # Gems derivation using customBundlerEnv
  gems =
    if hasGemset
    then customBundlerEnv {
      name = "${finalAppName}-gems";
      ruby = rubyPackage;
      gemdir = src;
      gemset = resolvedGemset;
      gemConfig = pkgs.defaultGemConfig // {
        ruby-vips = attrs: {
          buildInputs = [ pkgs.vips ];
        };
        rmagick = attrs: {
          buildInputs = [ pkgs.imagemagick pkgs.pkg-config ];
        };
        cairo = attrs: {
          buildInputs = [ pkgs.cairo pkgs.pkg-config ];
        };
      } // extraGemConfig;
    }
    else null;

  # App name (auto-detect or use provided)
  finalAppName =
    if appName != null
    then appName
    else "rails-app";

  # Helper derivations
  usrBinDerivation = pkgs.stdenv.mkDerivation {
    name = "usr-bin-env";
    buildInputs = [ pkgs.coreutils ];
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/usr/bin
      ln -sf ${pkgs.coreutils}/bin/env $out/usr/bin/env
    '';
  };

  tzinfo = pkgs.stdenv.mkDerivation {
    name = "tzinfo";
    buildInputs = [ pkgs.tzdata ];
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/usr/share
      ln -sf ${pkgs.tzdata}/share/zoneinfo $out/usr/share/zoneinfo
    '';
  };

  # Universal build inputs
  universalBuildInputs = import ./make-universal-build-inputs.nix {
    inherit pkgs frameworkInfo rubyPackage opensslPackage tailwindcssPackage extraBuildInputs;
  };

  # Shell hook
  shellPaths = import ./make-shell-paths.nix {
    inherit pkgs frameworkInfo opensslPackage;
  };

  defaultShellHook = ''
    ${shellPaths}
    export DATABASE_URL="postgresql://localhost/dummy_build_db"
  '';

  # Build script
  buildRailsApp = pkgs.writeShellScriptBin "make-rails-app-with-nix" (
    import ./make-rails-app-script.nix {
      inherit pkgs rubyPackage rubyMajorMinor;
      bundlerVersion = detectedBundlerVersion;
    }
  );

  # The actual build
  railsBuild =
    if hasGemset && gems != null
    then
      import ./make-rails-nix-build.nix {
        inherit pkgs universalBuildInputs rubyPackage rubyMajorMinor gems
                gccPackage opensslPackage usrBinDerivation tzinfo
                tailwindcssPackage bundlerPackage buildRailsApp defaultShellHook
                railsEnv railsBuilderVersion;
        appRevision = resolvedAppRevision;
        rubyVersion = detectedRubyVersion;
        inherit gccVersion opensslVersion;
        inherit src;
        appName = finalAppName;
        inherit bunDepsHash yarnDepsHash;
        inherit (frameworkInfo) needsRedis;
      }
    else
      # Fallback to bundler approach if no gemset.nix
      let
        buildRailsAppFallback = pkgs.writeShellScriptBin "make-ruby-app" (
          import ./make-generic-ruby-app-script.nix {
            inherit pkgs rubyPackage bundlerPackage rubyMajorMinor;
            bundlerVersion = detectedBundlerVersion;
            inherit framework;
          }
        );
      in (import ./make-rails-build.nix { pkgs = pkgsWithRuby; }) {
        rubyVersion = detectedRubyVersion;
        inherit src railsEnv railsBuilderVersion;
        appRevision = resolvedAppRevision;
        buildRailsApp = buildRailsAppFallback;
        appName = finalAppName;
        inherit bundlerPackage;
      };

in {
  # Main outputs
  app = railsBuild.app;
  shell = railsBuild.shell or null;
  dockerImage = railsBuild.dockerImage or null;

  # Components (for external Docker builds and advanced use)
  inherit gems rubyPackage bundlerPackage tailwindcssPackage;
  inherit universalBuildInputs;
  inherit rubyMajorMinor railsEnv;

  # Detected info (useful for debugging)
  detected = {
    rubyVersion = detectedRubyVersion;
    bundlerVersion = detectedBundlerVersion;
    tailwindVersion = detectedTailwindVersion;
    framework = framework;
    hasGemset = hasGemset;
    needsPostgresql = frameworkInfo.needsPostgresql;
    needsRedis = frameworkInfo.needsRedis;
    hasAssets = frameworkInfo.hasAssets;
    appRevision = resolvedAppRevision;
  };
}
