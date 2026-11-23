# imports/make-shell-paths.nix
#
# Returns shell-export lines that set PKG_CONFIG_PATH and LD_LIBRARY_PATH
# for the libs the framework needs (postgres / mysql / imagemagick / vips /
# cairo).
# Intended to be string-interpolated into a devShell shellHook.
#
# Usage:
#   shellPaths = import (ruby-builder + "/imports/make-shell-paths.nix") {
#     inherit pkgs frameworkInfo opensslPackage;
#   };
#   shellHook = ''
#     ${shellPaths}
#     export DATABASE_URL=...
#   '';
{
  pkgs,
  frameworkInfo,
  opensslPackage,
}:
let
  # Resolve outputs via makeLibraryPath / makeSearchPathOutput rather than
  # interpolating "''${pkg}/lib": for multi-output packages (curl, openssl,
  # vips, glib) the default output is `bin`, which has no lib/ at all, and
  # postgresql keeps libpq in its `lib` output. FFI gems that dlopen their
  # library (ethon -> libcurl, ruby-vips -> libvips + glib) need the real one.
  libs =
    [ pkgs.curl ]
    ++ pkgs.lib.optionals frameworkInfo.needsPostgresql [ pkgs.postgresql ]
    ++ pkgs.lib.optionals frameworkInfo.needsMysql [ pkgs.libmysqlclient ]
    ++ pkgs.lib.optionals frameworkInfo.needsImageMagick [ pkgs.imagemagick ]
    ++ pkgs.lib.optionals (frameworkInfo.needsLibVips or false) [ pkgs.vips pkgs.glib ]
    ++ pkgs.lib.optionals frameworkInfo.needsCairo [ pkgs.cairo ]
    ++ [ opensslPackage ];
  # openssl stays off PKG_CONFIG_PATH, as before.
  pkgconfLibs = pkgs.lib.remove opensslPackage libs;
in
  ''
    export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" pkgconfLibs}"
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath libs}"
  ''
