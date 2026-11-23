# imports/make-nodejs.nix
#
# Picks the Node.js package for an app: the version the app asks for, not
# whatever `pkgs.nodejs` happens to be.
#
# Resolution order:
#   1. `nodejsPackage` — explicit package from the caller, used as-is.
#   2. `nodeVersion`   — explicit version ("14.21.3", "16", "16.20"), else the
#      version detected from the app source (.nvmrc, .node-version,
#      .tool-versions, package.json volta.node / engines.node).
#      a. If the nixpkgs in use packages that major (pkgs.nodejs_20, …), use it.
#      b. Otherwise use the official prebuilt binary from nodejs.org, pinned in
#         ../nodejs-hashes.nix — the exact version for an exact pin, or the
#         newest release of the requested line.
#      c. Otherwise fail, saying what to set.
#   3. Nothing requested (or only ">=N", which the default satisfies) —
#      `pkgs.nodejs`.
#
# Usage:
#   nodejs = import (ruby-builder + "/imports/make-nodejs.nix") {
#     inherit pkgs;
#     src = ./.;
#     # nodeVersion = "16";          # optional override
#     # nodejsPackage = pkgs.nodejs_22;  # optional override
#   };
#   nodejs.package   # the derivation
#   nodejs.requested # version string asked for, or null
#   nodejs.source    # where the request came from, or null
{
  pkgs,
  src ? null,
  nodeVersion ? null,
  nodejsPackage ? null,
  nodejsHashes ? import ../nodejs-hashes.nix,
}: let
  lib = pkgs.lib;
  system = pkgs.stdenv.hostPlatform.system;

  detected =
    if src != null
    then (import ./detect-versions.nix).detectNodeVersionSpec { inherit src; }
    else { version = null; atLeast = null; source = null; raw = null; };

  requested =
    if nodeVersion != null
    then lib.removePrefix "v" (toString nodeVersion)
    else detected.version;
  source =
    if nodejsPackage != null then "nodejsPackage"
    else if nodeVersion != null then "nodeVersion"
    else detected.source;

  major = builtins.head (builtins.splitVersion requested);

  # `pkgs ? nodejs_18` can be true for an alias that throws once the major is
  # removed from nixpkgs, so force it.
  fromNixpkgs = let
    attempt = builtins.tryEval (pkgs."nodejs_${major}" or null);
    forced = builtins.tryEval (attempt.value.outPath or null);
  in
    if attempt.success && attempt.value != null && forced.success && forced.value != null
    then attempt.value
    else null;

  # Prebuilt releases matching the request that exist for this platform.
  prebuiltCandidates = builtins.filter
    (v: (v == requested || lib.hasPrefix "${requested}." v) && nodejsHashes.${v} ? ${system})
    (builtins.attrNames nodejsHashes);
  prebuiltVersion =
    if prebuiltCandidates == []
    then null
    else lib.last (builtins.sort (a: b: builtins.compareVersions a b < 0) prebuiltCandidates);

  platformSuffix = {
    "x86_64-linux" = "linux-x64.tar.xz";
    "aarch64-linux" = "linux-arm64.tar.xz";
    "x86_64-darwin" = "darwin-x64.tar.gz";
    "aarch64-darwin" = "darwin-arm64.tar.gz";
  };

  mkPrebuilt = version:
    pkgs.stdenv.mkDerivation {
      pname = "nodejs";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://nodejs.org/dist/v${version}/node-v${version}-${platformSuffix.${system}}";
        sha256 = nodejsHashes.${version}.${system};
      };

      nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
      buildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r bin include lib share $out/
        # npm / npx / corepack are "#!/usr/bin/env node" scripts; /usr/bin/env
        # doesn't exist in the build sandbox, so point them at this node.
        for f in $out/bin/*; do
          target=$(readlink -f "$f")
          if [ -f "$target" ] && [ "$(head -c 19 "$target")" = "#!/usr/bin/env node" ]; then
            sed -i "1s|.*|#!$out/bin/node|" "$target"
          fi
        done
        runHook postInstall
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        test "$($out/bin/node --version)" = "v${version}"
      '';

      meta = {
        description = "Node.js ${version} (official prebuilt binary)";
        homepage = "https://nodejs.org";
        license = lib.licenses.mit;
        mainProgram = "node";
        platforms = builtins.attrNames platformSuffix;
      };
    };

  package =
    if nodejsPackage != null then nodejsPackage
    else if requested == null then pkgs.nodejs
    else if fromNixpkgs != null then fromNixpkgs
    else if prebuiltVersion != null then mkPrebuilt prebuiltVersion
    else throw ''
      rails-builder: no Node.js ${requested} available for ${system}.
        Requested by: ${toString source}
        nixpkgs has no nodejs_${major}, and nodejs-hashes.nix has no matching
        prebuilt release for this platform.
      Fix one of:
        - set `nodeVersion` to a release line that exists (10 or newer)
        - pass `nodejsPackage` explicitly
        - re-run ./generate-nodejs-hashes.sh in rails-builder if the release is new
    '';
in {
  inherit package requested source detected;
}
