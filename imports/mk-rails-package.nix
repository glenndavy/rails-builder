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
# Usage in your flake:
#
#   let
#     railsBuild = rails-builder.lib.${system}.mkRailsPackage {
#       inherit pkgs;
#       src = rails-app-src;
#       # Optional overrides:
#       # appName = "my-app";
#       # rubyVersion = "3.2.0";  # auto-detected from .ruby-version if not specified
#     };
#   in {
#     packages.rails-app = railsBuild.app;
#     packages.docker-image = railsBuild.dockerImage;
#     packages.gems = railsBuild.gems;
#   }
#
{
  pkgs,
  src,            # Path to the Rails application source
  appName ? null, # Optional: Custom app name (defaults to "rails-app")
  rubyVersion ? null,     # Optional: Override Ruby version (auto-detected from .ruby-version)
  bundlerVersion ? null,  # Optional: Override Bundler version (auto-detected from Gemfile.lock)
  opensslVersion ? "3_2", # OpenSSL version: "3_2" (default) or "1_1" for legacy
  gccVersion ? "latest",  # GCC version
  extraBuildInputs ? [],  # Additional build inputs
  extraGemConfig ? {},    # Additional gem configuration
}:
let
  system = pkgs.system;

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

  # Framework detection
  frameworkInfo = detectFramework { inherit src; };
  framework = frameworkInfo.framework;

  # Ruby package
  rubyPackage = pkgs."ruby-${detectedRubyVersion}";
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

  # Bundler package with correct version from Gemfile.lock
  bundlerHashes = import ../bundler-hashes.nix;
  bundlerPackageBase = let
    hashInfo = bundlerHashes.${detectedBundlerVersion} or null;
  in
    if hashInfo != null
    then
      pkgs.buildRubyGem {
        inherit (hashInfo) sha256;
        ruby = rubyPackage;
        gemName = "bundler";
        version = detectedBundlerVersion;
        source.sha256 = hashInfo.sha256;
      }
    else
      pkgs.bundler.override { ruby = rubyPackage; };

  # Wrapper that provides both 'bundle' and 'bundler' commands
  bundlerPackage = pkgs.symlinkJoin {
    name = "bundler-${detectedBundlerVersion}-wrapped";
    paths = [ bundlerPackageBase ];
    postBuild = ''
      if [ -f $out/bin/bundler ] && [ ! -f $out/bin/bundle ]; then
        ln -s bundler $out/bin/bundle
      fi
    '';
  };

  # Tailwindcss package (if needed)
  tailwindcssHashes = import ../tailwindcss-hashes.nix;
  tailwindcssPackage =
    if detectedTailwindVersion != null && frameworkInfo.needsTailwindcss
    then
      import ./make-tailwindcss.nix {
        inherit pkgs tailwindcssHashes;
        version = detectedTailwindVersion;
      }
    else null;

  # Use customBundlerEnv from rails-builder (handles vendor/cache path gems)
  customBundlerEnv = import ./bundler-env { inherit pkgs; };

  # Check if gemset.nix exists
  hasGemset = builtins.pathExists (src + "/gemset.nix");

  # Gems derivation using customBundlerEnv
  gems =
    if hasGemset
    then customBundlerEnv {
      name = "${finalAppName}-gems";
      ruby = rubyPackage;
      gemdir = src;
      gemset = src + "/gemset.nix";
      gemConfig = pkgs.defaultGemConfig // {
        ruby-vips = attrs: {
          buildInputs = [ pkgs.vips ];
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
  universalBuildInputs = [
    rubyPackage
    opensslPackage
    pkgs.libxml2
    pkgs.libxslt
    pkgs.zlib
    pkgs.libyaml
    pkgs.curl
    pkgs.pkg-config
  ]
  ++ (if frameworkInfo.needsPostgresql then [ pkgs.libpqxx pkgs.postgresql ] else [])
  ++ (if frameworkInfo.needsMysql then [ pkgs.libmysqlclient pkgs.mysql80 ] else [])
  ++ (if frameworkInfo.needsSqlite then [ pkgs.sqlite ] else [])
  ++ (if frameworkInfo.hasAssets then [ pkgs.nodejs ] else [])
  ++ (if frameworkInfo.needsRedis then [ pkgs.redis ] else [])
  ++ (if frameworkInfo.needsImageMagick then [ pkgs.imagemagick ] else [])
  ++ (if frameworkInfo.needsLibVips then [ pkgs.vips ] else [])
  ++ (if tailwindcssPackage != null then [ tailwindcssPackage ] else [])
  ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    pkgs.nix-ld
    pkgs.stdenv.cc.cc.lib
  ]
  ++ extraBuildInputs;

  # Shell hook
  defaultShellHook = ''
    export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig${
      if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib/pkgconfig" else ""
    }${
      if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib/pkgconfig" else ""
    }"
    export LD_LIBRARY_PATH="${pkgs.curl}/lib${
      if frameworkInfo.needsPostgresql then ":${pkgs.postgresql}/lib" else ""
    }${
      if frameworkInfo.needsMysql then ":${pkgs.mysql80}/lib" else ""
    }:${opensslPackage}/lib"
    export DATABASE_URL="postgresql://localhost/dummy_build_db"
  '';

  # Build script
  buildRailsApp = pkgs.writeShellScriptBin "make-rails-app-with-nix" (
    import ./make-rails-app-script.nix {
      inherit pkgs rubyPackage bundlerVersion rubyMajorMinor;
    }
  );

  # The actual build
  railsBuild =
    if hasGemset && gems != null
    then
      import ./make-rails-nix-build.nix {
        inherit pkgs universalBuildInputs rubyPackage rubyMajorMinor gems
                gccPackage opensslPackage usrBinDerivation tzinfo
                tailwindcssPackage bundlerPackage buildRailsApp defaultShellHook;
        rubyVersion = detectedRubyVersion;
        inherit gccVersion opensslVersion;
        inherit src;
        appName = finalAppName;
        nodeModules = pkgs.runCommand "empty-node-modules" {} "mkdir -p $out/lib/node_modules";
        yarnOfflineCache = pkgs.runCommand "empty-yarn-cache" {} "mkdir -p $out";
      }
    else
      # Fallback to bundler approach if no gemset.nix
      let
        buildRailsAppFallback = pkgs.writeShellScriptBin "make-ruby-app" (
          import ./make-generic-ruby-app-script.nix {
            inherit pkgs rubyPackage bundlerPackage bundlerVersion rubyMajorMinor;
            inherit framework;
          }
        );
      in (import ./make-rails-build.nix { inherit pkgs; }) {
        rubyVersion = detectedRubyVersion;
        inherit src;
        buildRailsApp = buildRailsAppFallback;
        inherit appName bundlerPackage;
      };

in {
  # Main outputs
  app = railsBuild.app;
  shell = railsBuild.shell or null;
  dockerImage = railsBuild.dockerImage or null;

  # Components (for advanced use)
  inherit gems rubyPackage bundlerPackage tailwindcssPackage;
  inherit universalBuildInputs;
  inherit rubyMajorMinor;

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
  };
}
