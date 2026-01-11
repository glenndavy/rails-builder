# Precomputed SHA256 hashes for tailwindcss binaries
# Format: version.platform = "hash"
# Platforms: linux-x64, linux-arm64, macos-x64, macos-arm64
#
# To add a new version, run:
#   nix-prefetch-url "https://github.com/tailwindlabs/tailwindcss/releases/download/v${VERSION}/tailwindcss-${PLATFORM}"
#
{
  "4.1.16" = {
    "linux-x64" = "0l108g03psk81lhzxqpjlb1nbp5jnbdy6rsqgv6rrc6fcdm8grh9";
    "linux-arm64" = "1nlfp93dsg024r3liaj5sw22wx6b8v3fqv8hvbgw18fnyhsb8zln";
    "macos-x64" = "1lzmw0bw81x8pzfjz1n7w6f9mkp3i4h6zzc6z6wwljgjkg8axqpx";
    "macos-arm64" = "0zfzhyfyvcmkfg1aj9jxs46nq6nx24a6lkz56b54cmvz2sw49kg6";
  };
}
