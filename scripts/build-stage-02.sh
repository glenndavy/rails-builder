#!/bin/sh
set -e

# Validate BUILD_STAGE_3
if [ -z "$BUILD_STAGE_3" ]; then
  echo "Error: BUILD_STAGE_3 not set" >&2
  exit 1
fi

# Create builder branch
git checkout -b builder

# Update or initialize flake
if [ -e ./flake.nix ]; then
  nix flake update
else
  nix flake init -t github:glenndavy/rails-builder#new-app
  if [ ! -f ./flake.nix ]; then
    echo "Error: nix flake init failed to create flake.nix" >&2
    exit 1
  fi
  git add flake.nix
  git commit -m "Add flake.nix for Rails build"
fi
nix flake lock
if [ ! -f ./flake.lock ]; then
  echo "Error: nix flake lock failed to create flake.lock" >&2
  exit 1
fi
git add flake.lock
git commit -m "Add flake.lock"

# Verify flake.nix and Git status
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found after initialization" >&2
  exit 1
fi
echo "flake.nix contents in /source:"
#cat ./flake.nix
echo "Git status:"
git status
echo "Git log:"
git log --oneline -n 2

# Generate docker-entrypoint.sh in Rails root
# In build-stage-02.sh, update the here-document
cat <<'EOF' > docker-entrypoint.sh
#!/bin/sh
set -e
mkdir -p /builder
# Explicitly copy flake.nix and other files
if [ -f /source/flake.nix ]; then
  cp /source/flake.nix /builder/
else
  echo "Error: flake.nix not found in /source" >&2
  exit 1
fi
cp -r /source/* /builder/ 2>/dev/null || true
cd /builder
# Verify flake.nix in /builder
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found in /builder" >&2
  exit 1
fi
echo "flake.nix contents in /builder:"
cat ./flake.nix
# Run flakeVersion and commands
nix run .#flakeVersion --extra-experimental-features 'nix-command flakes'
echo "about to run nix develop"
nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && manage-redis start && build-rails-app && $BUILD_STAGE_3"
# Copy artifacts back to /source
rsync -a --delete /builder/vendor/bundle/ /source/vendor/bundle/
rsync -a --delete /builder/public/packs/ /source/public/packs/
EOF
chmod +x docker-entrypoint.sh
git add docker-entrypoint.sh
git commit -m "Add docker-entrypoint.sh for build orchestration"
echo "Generated docker-entrypoint.sh"
# Run Docker container
docker run -it --rm -v $(pwd):/source -w /builder -e HOME=/builder --entrypoint /source/docker-entrypoint.sh nixos/nix
