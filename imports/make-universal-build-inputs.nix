# imports/make-universal-build-inputs.nix
#
# Returns the framework-conditional buildInputs list for a Ruby/Rails build.
# Used by both the universal template and mk-rails-package so adding a new
# conditional dep (e.g. Elasticsearch) only needs editing one place.
#
# Usage:
#   universalBuildInputs = import (ruby-builder + "/imports/make-universal-build-inputs.nix") {
#     inherit pkgs frameworkInfo rubyPackage opensslPackage tailwindcssPackage;
#     extraBuildInputs = [ ... ];   # optional
#   };
{
  pkgs,
  frameworkInfo,
  rubyPackage,
  opensslPackage,
  tailwindcssPackage ? null,
  extraBuildInputs ? [],
}:
[
  rubyPackage
  opensslPackage
  pkgs.libxml2
  pkgs.libxslt
  pkgs.zlib
  pkgs.libyaml
  pkgs.curl
  pkgs.pkg-config
]
++ pkgs.lib.optionals frameworkInfo.needsPostgresql [ pkgs.libpqxx pkgs.postgresql ]
++ pkgs.lib.optionals frameworkInfo.needsMysql [ pkgs.libmysqlclient pkgs.mysql80 ]
++ pkgs.lib.optionals frameworkInfo.needsSqlite [ pkgs.sqlite ]
++ pkgs.lib.optionals frameworkInfo.hasAssets [ pkgs.nodejs ]
++ pkgs.lib.optionals frameworkInfo.needsRedis [ pkgs.redis ]
++ pkgs.lib.optionals frameworkInfo.needsImageMagick [ pkgs.imagemagick ]
++ pkgs.lib.optionals frameworkInfo.needsLibVips [ pkgs.vips ]
++ pkgs.lib.optionals frameworkInfo.needsCairo [ pkgs.cairo ]
# Browser drivers (capybara/selenium tests) only on Linux — darwin doesn't
# package chromedriver in a usable form for Nix builds.
++ pkgs.lib.optionals
    (frameworkInfo.needsBrowserDrivers or false && pkgs.stdenv.isLinux)
    [ pkgs.chromium pkgs.chromedriver ]
++ pkgs.lib.optionals (tailwindcssPackage != null) [ tailwindcssPackage ]
++ pkgs.lib.optionals pkgs.stdenv.isLinux [
  pkgs.nix-ld
  pkgs.stdenv.cc.cc.lib
]
++ extraBuildInputs
