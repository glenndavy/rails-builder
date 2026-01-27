# imports/make-tailwindcss.nix
# Provides tailwindcss CLI using bun + @tailwindcss/cli npm package
# The standalone GitHub binaries are broken (they're just bun runtime without tailwind bundled)
{
  pkgs,
  version,  # e.g., "4.1.18"
  tailwindcssHashes,  # import ../tailwindcss-hashes.nix
}: let
  system = pkgs.system;
  # Get the hash for this version and system (hashes are architecture-specific)
  versionInfo = tailwindcssHashes.${version} or null;
  npmDepsHash = if versionInfo != null && versionInfo.npmDeps ? ${system}
    then versionInfo.npmDeps.${system}
    else pkgs.lib.fakeHash;

in pkgs.stdenv.mkDerivation {
  pname = "tailwindcss";
  inherit version;

  # Fixed-output derivation that fetches npm packages
  src = pkgs.runCommand "tailwindcss-npm-deps-${version}" {
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = npmDepsHash;

    nativeBuildInputs = [ pkgs.bun pkgs.cacert ];

    # Required for network access
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  } ''
    export HOME=$TMPDIR
    export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache

    mkdir -p $out
    cd $out

    # Create minimal package.json
    echo '{"dependencies":{"@tailwindcss/cli":"${version}"}}' > package.json

    # Install with bun
    ${pkgs.bun}/bin/bun install --production

    # Remove cache files that may vary
    rm -rf $out/.bun-cache $out/bun.lockb 2>/dev/null || true
  '';

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin

    # Create wrapper script that runs tailwindcss via bun
    # Include libstdc++ for native node modules like @parcel/watcher
    # Set NODE_PATH so tailwindcss can resolve @import "tailwindcss" in CSS files
    cat > $out/bin/tailwindcss << WRAPPER
#!/usr/bin/env bash
export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:\$LD_LIBRARY_PATH"
export NODE_PATH="$src/node_modules:\$NODE_PATH"
exec ${pkgs.bun}/bin/bun $src/node_modules/@tailwindcss/cli/dist/index.mjs "\$@"
WRAPPER
    chmod +x $out/bin/tailwindcss

    # Also symlink node_modules for reference
    ln -s $src/node_modules $out/node_modules
  '';

  meta = with pkgs.lib; {
    description = "A utility-first CSS framework (via bun)";
    homepage = "https://tailwindcss.com";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
