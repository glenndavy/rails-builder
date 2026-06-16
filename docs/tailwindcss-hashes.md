# Tailwindcss Hash Management

rails-builder bundles tailwindcss CLI as a Nix-built artifact rather than
shelling out to a host-installed binary. Each tailwindcss version × platform
combo has a fixed-output-derivation hash that has to match what `bun install`
produces. This doc explains how those hashes are stored, refreshed, and
extended.

## What's stored where

- **`tailwindcss-hashes.nix`** — the registry. Per-version map of per-system
  SRI hashes for the bun-installed `node_modules` tree. The FOD in
  `imports/make-tailwindcss.nix` reads this; mismatches abort the build with
  `error: hash mismatch in fixed-output derivation`.

- **`tailwindcss-locks/<version>.lock`** — committed bun lockfile per version
  (text format, bun 1.2+). When present, `make-tailwindcss.nix` runs
  `bun install --frozen-lockfile`, which makes the install deterministic
  across bun versions. Versions without a lock get an unfrozen install and
  drift any time nixpkgs bumps bun (you'll get a hash mismatch).

- **`imports/make-tailwindcss.nix`** — the derivation builder. Reads the
  registry, picks the right hash for `pkgs.system`, copies the lockfile in
  if present, runs the install in an FOD, wraps the binary with a launcher.

- **`scripts/refresh-tailwindcss-hashes.sh`** — local refresh tool. Walks every
  version in the registry, runs the exact same install recipe the FOD uses,
  computes the hash, and updates the file in place (or `--check` mode for
  CI assertion).

- **`.github/workflows/refresh-tailwindcss-hashes.yml`** — automated refresh
  on weekly cron + manual dispatch.

## Why platform-specific hashes

Even with a frozen lockfile, `bun install` resolves different prebuilt
binaries per platform — `@tailwindcss/oxide-linux-x64.gem` on x86_64,
`@tailwindcss/oxide-linux-arm64.gem` on aarch64, etc. So the produced
`node_modules` differs byte-for-byte between platforms, and we need one
hash per `(version, system)` pair.

Currently supported platforms: `x86_64-linux`, `aarch64-linux`.

## CI workflow

`refresh-tailwindcss-hashes.yml` runs in two modes:

| Trigger | Mode | What happens |
|---|---|---|
| `pull_request` touching the registry / locks / script | check | Matrix runs `--check` on both architectures. Fails the PR if either hash drifted. |
| `workflow_dispatch` (manual) | refresh | Sequentially refreshes x86_64-linux then aarch64-linux. Pushes commits to a `bot/refresh-tailwindcss-hashes` branch. Auto-opens or updates a PR. |
| `schedule` weekly cron — Monday 06:00 UTC | refresh | Same as workflow_dispatch. |

Cron is configured at line 13 of the workflow:
```yaml
schedule:
  - cron: '0 6 * * 1'   # weekly, Monday 06:00 UTC
```

To dispatch manually:
```bash
gh workflow run refresh-tailwindcss-hashes.yml -R glenndavy/rails-builder
```

To watch a run:
```bash
gh run watch -R glenndavy/rails-builder
```

The runners are `ubuntu-latest` (x86_64) and `ubuntu-24.04-arm` (native ARM).
Both are free on public repos.

## Running the script locally

Requires `bun`, `jq`, `nix` in PATH (the `nix shell` invocation handles the
first two):

```bash
cd ~/w/rails-builder

# Refresh in place — updates only this machine's platform column.
nix shell nixpkgs#bun nixpkgs#jq -c bash scripts/refresh-tailwindcss-hashes.sh

# Check-only — exit 1 if any drift, no file changes.
nix shell nixpkgs#bun nixpkgs#jq -c bash scripts/refresh-tailwindcss-hashes.sh --check
```

Output legend:
- `✓ <version>: <hash> (unchanged)` — already correct
- `Δ <version>: <old> → <new>` — drift detected, will rewrite
- `+ <version>: <hash> (new for <system>)` — adding a new platform column

Takes 5–10 minutes for the full set (~30 versions × a few seconds of bun
install each).

## Adding a new tailwindcss version

1. Edit `tailwindcss-hashes.nix` and append the new version with empty deps:
   ```nix
   "4.4.0" = {
     npmDeps = {};
   };
   ```

2. (Recommended) Pin a bun lockfile so future bun bumps don't drift the hash:
   ```bash
   cd $(mktemp -d)
   printf '{"dependencies":{"@tailwindcss/cli":"4.4.0"}}\n' > package.json
   nix shell nixpkgs#bun -c bun install --save-text-lockfile
   cp bun.lock ~/w/rails-builder/tailwindcss-locks/4.4.0.lock
   ```

3. Run the refresh script locally to fill your platform's hash:
   ```bash
   cd ~/w/rails-builder
   nix shell nixpkgs#bun nixpkgs#jq -c bash scripts/refresh-tailwindcss-hashes.sh
   ```

4. Commit and push:
   ```bash
   git add tailwindcss-hashes.nix tailwindcss-locks/4.4.0.lock
   git commit -m "Add tailwindcss 4.4.0"
   git push origin master
   ```

5. Either wait for Monday's cron run to fill in the other architecture, or
   dispatch manually:
   ```bash
   gh workflow run refresh-tailwindcss-hashes.yml -R glenndavy/rails-builder
   ```

6. Review the bot's PR and merge. The new version is now fully supported.

## Adding a new platform

E.g. `aarch64-darwin` (Apple Silicon) or `x86_64-darwin` (Intel Mac):

1. Add a new runner to the matrix in
   `.github/workflows/refresh-tailwindcss-hashes.yml`. macOS runners are
   `macos-13` (Intel) and `macos-14` / `macos-latest` (ARM).
2. The refresh script auto-detects `builtins.currentSystem` and updates only
   that column — no script changes needed.
3. First CI run on the new platform will add the column for every existing
   version.

`make-tailwindcss.nix` already handles missing system entries by falling back
to `pkgs.lib.fakeHash` — builds for unsupported platforms fail loudly with
the actual `got:` hash so the registry can be filled.

## Why this complexity exists

The alternative is fetching tailwindcss as a runtime dependency (e.g. via
`bundle exec` invoking the host's `npx`). That breaks Nix's reproducibility
guarantees: the build's output would depend on whatever bun + npm registry
state existed at build time. Pre-resolving via FOD + committed lockfile +
recorded hash gives us:

- Reproducible builds across machines
- Cache hits from the binary cache (since the FOD output is content-addressed)
- Network access during the bun install (FODs are allowed)
- Failure mode that's loud (hash mismatch) rather than silent (wrong gems
  installed)

The cost is hash bookkeeping — which the automation here is meant to take
off your plate.
