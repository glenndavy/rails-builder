# imports/make-bundler-package.nix
#
# Constructs a ruby-version-matched bundler derivation. Looks up the version
# in bundler-hashes.nix for a content-addressed buildRubyGem; falls back to
# nixpkgs' default bundler (overridden for the target ruby) if the version
# isn't catalogued.
#
# A postInstall hook adds a `bundle` → `bundler` symlink if the gem only
# shipped the `bundler` binary (older versions). Uses overrideAttrs rather
# than symlinkJoin so the result keeps the underlying gem derivation's
# attributes (.version, .override, .ruby, .gemPath, ...) — downstream
# consumers like bundled-common/functions.nix read these.
#
# Usage:
#   bundlerPackage = import (ruby-builder + "/imports/make-bundler-package.nix") {
#     inherit pkgs;
#     ruby = rubyPackage;             # ruby derivation to build against
#     version = bundlerVersion;       # version string, e.g. "2.5.22"
#   };
{
  pkgs,
  ruby,
  version,
}:
let
  bundlerHashes = import ../bundler-hashes.nix;
  hashInfo = bundlerHashes.${version} or null;
  base =
    if hashInfo != null
    then pkgs.buildRubyGem {
      inherit ruby;
      inherit (hashInfo) sha256;
      gemName = "bundler";
      inherit version;
      source.sha256 = hashInfo.sha256;
    }
    else pkgs.bundler.override { inherit ruby; };
in
  base.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      if [ -f $out/bin/bundler ] && [ ! -f $out/bin/bundle ]; then
        ln -s bundler $out/bin/bundle
      fi
    '';
  })
