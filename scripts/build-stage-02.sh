#!/bin/sh
# Version: 2.0.11
set -e

# Validate BUILD_STAGE_3
if [ -z "$BUILD_STAGE_3" ]; then
  echo "Error: BUILD_STAGE_3 not set" >&2
  exit 1
fi
# Validate BUILD_STAGE_3 syntax
if ! sh -n -c "$BUILD_STAGE_3" >/dev/null 2>&1; then
  echo "Error: Invalid BUILD_STAGE_3 syntax: $BUILD_STAGE_3" >&2
  exit 1
fi
export BUILD_STAGE_3=" && $BUILD_STAGE_3"
echo "DEBUG: BUILD_STAGE_3=$BUILD_STAGE_3" >&2

# Create builder branch
git checkout -b builder

# Update or initialize flake
if [ -e ./flake.nix ]; then
  nix flake update
else
  nix flake init -t github:glenndavy/rails-builder${REF:+?ref=$REF}${REV:+${REF:+&}rev=$REV}#new-app
  if [ ! -f ./flake.nix ]; then
    echo "Error: nix flake init failed to create flake.nix" >&2
    exit 1
  fi
  git add flake.nix
  git commit -m "Add flake.nix for Rails build" || true
fi
nix flake lock
if [ ! -f ./flake.lock ]; then
  echo "Error: nix flake lock failed to create flake.lock" >&2
  exit 1
fi
git add flake.lock
git commit -m "Add flake.lock" || true

# Verify flake.nix and Git status
if [ -f ./flake.nix ]; then
  echo "Git status:"
  git status
  echo "Git log:"
  git log --oneline -n 2
else
  echo "Error: flake.nix not found after initialization" >&2
  exit 1
fi

# Generate docker-entrypoint.sh in Rails root
cat <<'EOF' > docker-entrypoint.sh
#!/bin/bash
set -e
echo "DEBUG: Starting docker-entrypoint.sh" >&2
# Ensure PATH includes /sbin and /bin
export PATH=/sbin:/bin:$PATH
# Debug command locations
echo "DEBUG: groupadd location: $(which groupadd)" >&2
echo "DEBUG: useradd location: $(which useradd)" >&2
echo "DEBUG: chown location: $(which chown)" >&2
# Debug Nix version
echo "DEBUG: Nix version: $(nix --version)" >&2
# Configure nix.conf for download-buffer-size, experimental features, and insecure packages
mkdir -p /etc/nix
cat <<NIX_CONF > /etc/nix/nix.conf
download-buffer-size = 83886080
experimental-features = nix-command flakes
accept-flake-config = true
permittedInsecurePackages = ruby-2.7.5
NIX_CONF
# Allow insecure packages
export NIXPKGS_ALLOW_INSECURE=1
echo "DEBUG: NIXPKGS_ALLOW_INSECURE=$NIXPKGS_ALLOW_INSECURE" >&2
echo "DEBUG: nix.conf contents:" >&2
cat /etc/nix/nix.conf >&2
# Detect UID of /source
SOURCE_UID=$(stat -c %u /source)
echo "DEBUG: Source UID: $SOURCE_UID" >&2
# Create app-builder user with matching UID
groupadd -g $SOURCE_UID app-builder
useradd -u $SOURCE_UID -g $SOURCE_UID -d /builder -s /bin/bash app-builder
echo "DEBUG: Created app-builder user with UID $SOURCE_UID" >&2
# Set up /builder (owned by app-builder)
mkdir -p /builder
chown app-builder:app-builder /builder
# Copy source files, preserving ownership
cp -r /source/* /source/.* /builder/ 2>/dev/null || true
cd /builder
# Verify files in /builder
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found in /builder" >&2
  exit 1
fi
if [ ! -f ./Gemfile ]; then
  echo "Warning: Gemfile not found in /builder" >&2
fi
echo ".ruby-version contents in /builder (if present):"
[ -f ./.ruby-version ] && cat ./.ruby-version || echo "No .ruby-version"
# Debug Ruby version
echo "DEBUG: Ruby version before build: $(gosu app-builder nix develop .#buildShell --allow-insecure --extra-experimental-features 'nix-command flakes' --command ruby -v)" >&2
# Run commands in buildShell, sequencing services
gosu app-builder nix run .#flakeVersion --allow-insecure --extra-experimental-features 'nix-command flakes'
echo "about to run nix develop"
echo "DEBUG: BUILD_STAGE_3=$BUILD_STAGE_3" >&2
echo "DEBUG: sh -c command: manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3" >&2
gosu app-builder nix develop .#buildShell --allow-insecure --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3"
echo "DEBUG: docker-entrypoint.sh completed" >&2
EOF
chmod +x docker-entrypoint.sh
git add docker-entrypoint.sh
git commit -m "Add docker-entrypoint.sh for build orchestration" || true
echo "Generated docker-entrypoint.sh"
# Ensure Nix store volume exists
docker volume create nix-store || true
# Run Docker container with increased memory and CPU
docker run -it --rm --memory=16g --cpus=4 -v $(pwd):/source -v nix-store:/nix/store -w /builder -e HOME=/builder --entrypoint /source/docker-entrypoint.sh opscare-builder:latest
