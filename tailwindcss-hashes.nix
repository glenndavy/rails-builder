# Precomputed SHA256 hashes for tailwindcss npm dependencies
# Format: version.npmDeps = "hash"
#
# The hash is for the full node_modules directory created by `bun install @tailwindcss/cli@VERSION`
# To add a new version, set npmDeps = "" and build - nix will show the correct hash.
#
{
  "4.1.16" = {
    npmDeps = "";  # TODO: compute when needed
  };
  "4.1.18" = {
    npmDeps = "sha256-UABgFF3c029YymHjsazwWUw9BLzR9bP0EX6FN0MojEA=";
  };
}
