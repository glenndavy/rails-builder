#!/bin/sh
# Version: 2.0.31
set -e
export STAGE_2_VERSION=2.0.31
echo "Stage 2 version: ${STAGE_2_VERSION}"

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
echo "DEBUG: Starting docker-entrypoint.sh : ${STAGE_2_VERSION}" >&2
# Ensure PATH includes /sbin and /bin
export PATH=/sbin:/bin:$PATH
# Set SSL certificate file
export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
echo "DEBUG: SSL_CERT_FILE=$SSL_CERT_FILE" >&2
# Relax Nix Git ownership checks
export NIX_GIT_CHECKOUT_SAFE=0
echo "DEBUG: NIX_GIT_CHECKOUT_SAFE=$NIX_GIT_CHECKOUT_SAFE" >&2
# Debug Nix version and nix.conf
echo "DEBUG: Nix version: $(/bin/nix --version 2>/dev/null || echo 'nix not found')" >&2
cat /etc/nix/nix.conf 2>/dev/null || echo "DEBUG: /etc/nix/nix.conf not found" >&2
# Allow insecure packages
export NIXPKGS_ALLOW_INSECURE=1
echo "DEBUG: NIXPKGS_ALLOW_INSECURE=$NIXPKGS_ALLOW_INSECURE" >&2
# Debug /nix/store permissions
echo "DEBUG: /nix/store permissions: $(ls -ld /nix/store 2>/dev/null)" >&2
# Detect UID of /source
SOURCE_UID=$(stat -c %u /source)
echo "DEBUG: Source UID: $SOURCE_UID" >&2
# Update app-builder UID and GID if needed
if [ "$SOURCE_UID" != "1000" ]; then
  usermod -u $SOURCE_UID app-builder
  groupmod -g $SOURCE_UID app-builder
  echo "DEBUG: Updated app-builder UID to $SOURCE_UID" >&2
else
  echo "DEBUG: app-builder UID already matches $SOURCE_UID" >&2
fi
# Set ownership of /home/app-builder
chown $SOURCE_UID:$SOURCE_UID /home/app-builder
# Set /nix/store group permissions
chmod -R g+w /nix/store
echo "DEBUG: /nix/store permissions after: $(ls -ld /nix/store 2>/dev/null)" >&2
cd /source
# Verify files in /source
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found in /source" >&2
  exit 1
fi
if [ ! -f ./Gemfile ]; then
  echo "Warning: Gemfile not found in /source" >&2
fi
echo ".ruby-version contents in /source (if present):"
[ -f ./.ruby-version ] && cat ./.ruby-version || echo "No .ruby-version"
# Debug Ruby version
echo "DEBUG: Ruby version before build: $(env SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt gosu app-builder /bin/nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command ruby -v 2>/dev/null || echo 'nix develop failed')" >&2
# Run commands in buildShell
env SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt gosu app-builder /bin/nix run .#flakeVersion --extra-experimental-features 'nix-command flakes'
echo "about to run nix develop"
echo "DEBUG: BUILD_STAGE_3=$BUILD_STAGE_3" >&2
echo "DEBUG: sh -c command: manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3" >&2
env SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt gosu app-builder /bin/nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3"
echo "DEBUG: docker-entrypoint.sh completed" >&2
EOF
chmod +x docker-entrypoint.sh
git add docker-entrypoint.sh
git commit -m "Add docker-entrypoint.sh for build orchestration" || true
echo "Generated docker-entrypoint.sh"
# Run Docker container with increased memory and CPU
docker run -it --rm --memory=16g --cpus=4 -v $(pwd):/source -w /source -e HOME=/home/app-builder --entrypoint /source/docker-entrypoint.sh opscare:latest
