# Precomputed SHA256 hashes for tailwindcss npm dependencies
# Format: version.npmDeps.${system} = "hash"
#
# The hash is for the full node_modules directory created by `bun install @tailwindcss/cli@VERSION`
# Hashes are architecture-specific due to platform-specific npm packages.
# To add a new version, set npmDeps = {} and build - nix will show the correct hash.
#
{
  "4.1.16" = {
    npmDeps = {}; # TODO: compute when needed
  };
  "4.1.18" = {
    npmDeps = {
      "x86_64-linux" = "sha256-hRVDPtp3BdPqKIaBOSkBqXix68BHFd4VGGc4kQhUn7A=";
      "aarch64-linux" = "sha256-UABgFF3c029YymHjsazwWUw9BLzR9bP0EX6FN0MojEA=";
      "aarch64-darwin" = "sha256-g9/0IYGR02kiVftd0Zul5HJP2TQSJo4LknmbN8tV4D8=";
    };
  };
}
