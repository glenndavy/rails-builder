#!/usr/bin/env bash
# Refresh tailwindcss-hashes.nix for the current platform.
#
# Iterates every version in tailwindcss-hashes.nix, runs the same
# `bun install` recipe make-tailwindcss.nix uses (with the committed
# bun.lock when present), computes the SRI hash, and updates the file
# in place when drift is detected. Adds entries for the current platform
# if missing.
#
# Run locally on each platform you want hashes for, OR via the
# refresh-tailwindcss-hashes GH workflow which runs on x86_64-linux +
# aarch64-linux runners and PRs the result.
#
# Usage: scripts/refresh-tailwindcss-hashes.sh [--check]
#   --check   exit 1 if any hash would change (CI assertion mode);
#             default behavior updates the file.
#
# Requires: nix, bun, jq.

set -euo pipefail

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then CHECK_ONLY=1; fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HASHES="$ROOT/tailwindcss-hashes.nix"
LOCKS="$ROOT/tailwindcss-locks"

system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
echo "Refreshing tailwindcss hashes for system: $system"

versions=$(nix eval --json --file "$HASHES" --apply 'builtins.attrNames' | jq -r '.[]' | sort -V)
echo "Found $(echo "$versions" | wc -l) versions in $HASHES"

drift=0
declare -A new_hashes

for v in $versions; do
  # Current hash for this platform (or empty if missing)
  current=$(nix eval --raw --file "$HASHES" \
    --apply "h: h.\"$v\".npmDeps.\"$system\" or \"\"" 2>/dev/null || echo "")

  # Mimic the FOD recipe: package.json + (optional) bun.lock, then
  # bun install --production --frozen-lockfile --ignore-scripts.
  build_dir=$(mktemp -d)
  printf '{"dependencies":{"@tailwindcss/cli":"%s"}}\n' "$v" > "$build_dir/package.json"
  if [[ -f "$LOCKS/$v.lock" ]]; then
    cp "$LOCKS/$v.lock" "$build_dir/bun.lock"
    frozen="--frozen-lockfile"
  else
    frozen=""
  fi
  (cd "$build_dir" && HOME="$build_dir" bun install --production --no-progress \
      --ignore-scripts $frozen 2>&1 | tail -1) || {
    echo "  ⚠ $v: bun install failed; skipping"
    rm -rf "$build_dir"
    continue
  }

  hash_dir=$(mktemp -d)
  cp -r "$build_dir/node_modules" "$hash_dir/"
  computed=$(nix hash path --type sha256 --sri "$hash_dir")
  rm -rf "$build_dir" "$hash_dir"

  if [[ "$current" == "$computed" ]]; then
    echo "  ✓ $v: $computed (unchanged)"
  elif [[ -z "$current" ]]; then
    echo "  + $v: $computed (new for $system)"
    new_hashes[$v]="$computed"
    drift=1
  else
    echo "  Δ $v: $current → $computed"
    new_hashes[$v]="$computed"
    drift=1
  fi
done

if [[ $drift -eq 0 ]]; then
  echo "All hashes up-to-date for $system."
  exit 0
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo "Drift detected. Run without --check to update $HASHES."
  exit 1
fi

# Patch tailwindcss-hashes.nix in place. For each version with drift:
# - If the system entry exists, replace its value
# - If the system entry doesn't exist, insert a new line before the
#   closing `};` of the npmDeps block
for v in "${!new_hashes[@]}"; do
  h="${new_hashes[$v]}"
  has_entry=$(nix eval --json --file "$HASHES" \
    --apply "f: (f.\"$v\".npmDeps ? \"$system\")" 2>/dev/null || echo "false")

  if [[ "$has_entry" == "true" ]]; then
    # Replace existing system value within this version block.
    # Match the version's npmDeps subblock and substitute just the
    # one system line. Using awk for clarity over multi-line sed.
    awk -v ver="$v" -v sys="$system" -v hash="$h" '
      $0 ~ "^  \"" ver "\" = \\{" { in_v=1 }
      in_v && /npmDeps = \{/ { in_d=1 }
      in_d && $0 ~ "\"" sys "\" = " {
        sub(/"sha256-[^"]*"/, "\"" hash "\"")
      }
      in_d && /^    \};$/ { in_d=0 }
      in_v && /^  \};$/ { in_v=0 }
      { print }
    ' "$HASHES" > "$HASHES.tmp" && mv "$HASHES.tmp" "$HASHES"
  else
    # Insert a new system line inside the npmDeps block of this version.
    awk -v ver="$v" -v sys="$system" -v hash="$h" '
      $0 ~ "^  \"" ver "\" = \\{" { in_v=1 }
      in_v && /npmDeps = \{/ { in_d=1; print; next }
      in_d && /^    \};$/ {
        print "      \"" sys "\" = \"" hash "\";"
        in_d=0
      }
      in_v && /^  \};$/ { in_v=0 }
      { print }
    ' "$HASHES" > "$HASHES.tmp" && mv "$HASHES.tmp" "$HASHES"
  fi
  echo "  → updated $HASHES: $v.$system = $h"
done

echo "Done. Inspect $HASHES, commit, push."
