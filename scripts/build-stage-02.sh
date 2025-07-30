#!/bin/sh
# Version: 2.0.41
set -e
export STAGE_2_VERSION=2.0.42
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

# Generate prepare-build.sh in Rails root
cat <<'EOF' > prepare-build.sh
#!/bin/bash
set -e
echo "DEBUG: Starting prepare-build.sh : ${STAGE_2_VERSION}" >&2
# Ensure PATH includes Nix and system binaries
export PATH=~/.nix-profile/bin:/bin:/sbin:$PATH
# Set SSL certificate file
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
echo "DEBUG: SSL_CERT_FILE=$SSL_CERT_FILE" >&2
# Debug Nix version and nix.conf
echo "DEBUG: Nix version: $(nix --version 2>/dev/null || echo 'nix not found')" >&2
cat /etc/nix/nix.conf 2>/dev/null || echo "DEBUG: /etc/nix/nix.conf not found" >&2
# Allow insecure packages
export NIXPKGS_ALLOW_INSECURE=1
echo "DEBUG: NIXPKGS_ALLOW_INSECURE=$NIXPKGS_ALLOW_INSECURE" >&2
# Debug /nix/store permissions
echo "DEBUG: /nix/store permissions: $(ls -ld /nix/store 2>/dev/null)" >&2
# Verify files in /source
if [ -f ./flake.nix ]; then
  echo "DEBUG: Found flake.nix in /source" >&2
else
  echo "Error: flake.nix not found in /source" >&2
  exit 1
fi
if [ -f ./Gemfile ]; then
  echo "DEBUG: Found Gemfile in /source" >&2
else
  echo "Warning: Gemfile not found in /source" >&2
fi
echo ".ruby-version contents in /source (if present):"
[ -f ./.ruby-version ] && cat ./.ruby-version || echo "No .ruby-version"
# Debug Ruby version
echo "DEBUG: Ruby version before build: $(nix develop --impure .#buildShell --extra-experimental-features 'nix-command flakes' --command ruby -v 2>/dev/null || echo 'nix develop failed')" >&2
# Run commands in buildShell
nix run .#flakeVersion --extra-experimental-features 'nix-command flakes'
echo "about to run nix develop"
echo "DEBUG: BUILD_STAGE_3=$BUILD_STAGE_3" >&2
echo "DEBUG: sh -c command: manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3" >&2
nix develop .#buildShell --impure --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && sleep 5 && manage-redis start && sleep 5 && build-rails-app $BUILD_STAGE_3"
echo "DEBUG: prepare-build.sh completed" >&2
EOF
chmod +x prepare-build.sh
git add prepare-build.sh
git commit -m "Add prepare-build.sh for build orchestration" || true
echo "Generated prepare-build.sh"
# Run Docker container with increased memory and CPU
#docker run -it --rm --memory=16g --cpus=4 --user 1000:1000 -v $(pwd):/source -w /source -e HOME=/home/app-builder --entrypoint /source/prepare-build.sh opscare-builder:latest
echo $PWD
./prepare-build.sh
