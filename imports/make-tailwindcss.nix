# imports/make-tailwindcss.nix
# Fetches the exact tailwindcss version needed based on Gemfile.lock
# Uses precomputed hashes from tailwindcss-hashes.nix
{
  pkgs,
  version,  # e.g., "4.1.16"
  tailwindcssHashes,  # import ../tailwindcss-hashes.nix
}: let
  # Platform mapping for tailwindcss releases
  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "macos-x64";
    "aarch64-darwin" = "macos-arm64";
  };

  platform = platformMap.${pkgs.stdenv.hostPlatform.system} or (throw "Unsupported platform: ${pkgs.stdenv.hostPlatform.system}");

  # Tailwind v4 uses different release naming
  binaryName = "tailwindcss-${platform}";

  # Get hash from precomputed hashes
  versionHashes = tailwindcssHashes.${version} or null;
  hash = if versionHashes != null
    then versionHashes.${platform} or (throw "No hash for tailwindcss ${version} on ${platform}")
    else throw "No hashes for tailwindcss version ${version}. Add to tailwindcss-hashes.nix";

  # Fetch the binary from GitHub releases
  tailwindcssBinary = pkgs.fetchurl {
    url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${version}/${binaryName}";
    sha256 = hash;
  };

in pkgs.stdenv.mkDerivation {
  pname = "tailwindcss";
  inherit version;

  src = tailwindcssBinary;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/tailwindcss
    chmod +x $out/bin/tailwindcss
  '';

  meta = with pkgs.lib; {
    description = "A utility-first CSS framework";
    homepage = "https://tailwindcss.com";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
