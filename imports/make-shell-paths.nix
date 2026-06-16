# imports/make-shell-paths.nix
#
# Returns shell-export lines that set PKG_CONFIG_PATH and LD_LIBRARY_PATH
# for the libs the framework needs (postgres / mysql / imagemagick / cairo).
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
  pkgconfPath = ":${pkgs.postgresql}/lib/pkgconfig";
  mysqlPkgconfPath = ":${pkgs.mysql80}/lib/pkgconfig";
  imagemagickPkgconfPath = ":${pkgs.imagemagick.dev}/lib/pkgconfig";
  cairoPkgconfPath = ":${pkgs.cairo.dev}/lib/pkgconfig";

  postgresLibPath = ":${pkgs.postgresql}/lib";
  mysqlLibPath = ":${pkgs.mysql80}/lib";
  imagemagickLibPath = ":${pkgs.imagemagick}/lib";
  cairoLibPath = ":${pkgs.cairo}/lib";

  optStr = cond: s: if cond then s else "";
in
  ''
    export PKG_CONFIG_PATH="${pkgs.curl.dev}/lib/pkgconfig${
      optStr frameworkInfo.needsPostgresql pkgconfPath
    }${
      optStr frameworkInfo.needsMysql mysqlPkgconfPath
    }${
      optStr frameworkInfo.needsImageMagick imagemagickPkgconfPath
    }${
      optStr frameworkInfo.needsCairo cairoPkgconfPath
    }"
    export LD_LIBRARY_PATH="${pkgs.curl}/lib${
      optStr frameworkInfo.needsPostgresql postgresLibPath
    }${
      optStr frameworkInfo.needsMysql mysqlLibPath
    }${
      optStr frameworkInfo.needsImageMagick imagemagickLibPath
    }${
      optStr frameworkInfo.needsCairo cairoLibPath
    }:${opensslPackage}/lib"
  ''
