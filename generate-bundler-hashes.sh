#!/usr/bin/env bash
set -e
VERSIONS_FILE="bundler-versions.txt"
OUTPUT_FILE="bundler-hashes.nix"
echo "{" > "$OUTPUT_FILE"
while IFS= read -r version; do
  echo "Fetching bundler-$version..."
  gem_url="https://rubygems.org/downloads/bundler-$version.gem"
  sha256=$(nix-prefetch-url "$gem_url" 2>/dev/null)
  echo "  \"$version\" = {" >> "$OUTPUT_FILE"
  echo "    url = \"$gem_url\";" >> "$OUTPUT_FILE"
  echo "    sha256 = \"$sha256\";" >> "$OUTPUT_FILE"
  echo "  };" >> "$OUTPUT_FILE"
done < "$VERSIONS_FILE"
echo "}" >> "$OUTPUT_FILE"
echo "Generated $OUTPUT_FILE"
