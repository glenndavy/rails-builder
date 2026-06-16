# imports/make-safe-shell.nix
#
# A minimal "break-glass" devShell for when the regular shells (with-bundix,
# with-bundler, default) won't eval — wrong SHAs in gemset.nix, a missing
# gemset.nix entirely, a broken bundlerEnv, a tailwindcss hash drift, etc.
#
# Contains *only*:
#   - the project's ruby (detected from `<src>/.ruby-version` if available)
#   - a version-matched bundler (via make-bundler-package.nix)
#   - the C toolchain & libs you need to `bundle install` from scratch
#
# It does NOT use bundlerEnv, does NOT read gemset.nix, does NOT pull
# tailwindcss or any JS deps, and does NOT evaluate anything that could fail
# on a malformed lockfile. Entering it should always succeed.
#
# Once inside you can `bundle install --path vendor/bundle` to bootstrap
# enough of the app to diagnose what broke.
#
# Usage from an external flake:
#   devShells.${system}.safe = rails-builder.lib.${system}.mkSafeShell {
#     inherit pkgs;
#     src = ./.;                  # optional: lets ruby version auto-detect
#     # rubyVersion = "3.3.0";    # optional override
#     # bundlerVersion = "2.5.22"; # optional override
#   };
#
# Or directly:
#   nix develop github:glenndavy/rails-builder#safe
{
  pkgs,
  src ? null,
  rubyVersion ? null,
  bundlerVersion ? null,
}:
let
  versionDetection = import ./detect-versions.nix;

  detectedRubyVersion =
    if rubyVersion != null then rubyVersion
    else if src != null then versionDetection.detectRubyVersion src
    else "3.3.0";

  detectedBundlerVersion =
    if bundlerVersion != null then bundlerVersion
    else if src != null then versionDetection.detectBundlerVersion src
    else "2.5.22";

  rubyPackage =
    if pkgs ? "ruby-${detectedRubyVersion}"
    then pkgs."ruby-${detectedRubyVersion}"
    else pkgs.ruby;

  bundlerPackage = import ./make-bundler-package.nix {
    inherit pkgs;
    ruby = rubyPackage;
    version = detectedBundlerVersion;
  };
in
  pkgs.mkShell {
    name = "rails-safe-shell";

    buildInputs = [
      rubyPackage
      bundlerPackage
      pkgs.pkg-config
      pkgs.gnumake
      pkgs.gcc
      pkgs.git
      pkgs.openssl
      pkgs.zlib
      pkgs.libyaml
      pkgs.libxml2
      pkgs.libxslt
      pkgs.curl
      pkgs.sqlite
    ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.nix-ld
      pkgs.stdenv.cc.cc.lib
    ];

    shellHook = ''
      echo ""
      echo "  ┌──────────────────────────────────────────────────────────┐"
      echo "  │ rails-builder safe shell                                 │"
      echo "  │                                                          │"
      echo "  │   ruby:     ${detectedRubyVersion}"
      echo "  │   bundler:  ${detectedBundlerVersion}"
      echo "  │                                                          │"
      echo "  │ No bundlerEnv, no gemset.nix, no JS deps — just enough   │"
      echo "  │ to bootstrap an app whose normal shells won't eval.      │"
      echo "  │                                                          │"
      echo "  │ Try:   bundle install --path vendor/bundle               │"
      echo "  └──────────────────────────────────────────────────────────┘"
      echo ""
      export BUNDLE_PATH="vendor/bundle"
      export GEM_HOME="$PWD/vendor/bundle"
      export PATH="$GEM_HOME/bin:$PATH"
    '';
  }
