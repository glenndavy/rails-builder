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
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found after initialization" >&2
  exit 1
fi
echo "Git status:"
git status
echo "Git log:"
git log --oneline -n 2

# Generate docker-entrypoint.sh in Rails root
cat <<'EOF' > docker-entrypoint.sh
#!/bin/sh
set -e
mkdir -p /builder
# Explicitly copy flake.nix and .ruby-version
if [ -f /source/flake.nix ]; then
  cp /source/flake.nix /builder/
else
  echo "Error: flake.nix not found in /source" >&2
  exit 1
fi
if [ -f /source/.ruby-version ]; then
  cp /source/.ruby-version /builder/
else
  echo "Warning: .ruby-version not found in /source" >&2
fi
# Copy all files, including .*
shopt -s dotglob
cp -r /source/* /builder/ 2>/dev/null || true
cd /builder
# Verify files in /builder
if [ ! -f ./flake.nix ]; then
  echo "Error: flake.nix not found in /builder" >&2
  exit 1
fi
if [ ! -f ./.ruby-version ]; then
  echo "Error: .ruby-version not found in /builder" >&2
  exit 1
fi
echo ".ruby-version contents in /builder:"
cat ./.ruby-version
# Run commands in buildShell
nix run .#flakeVersion  --extra-experimental-features 'flakes nix-command'
echo "about to run nix develop"
nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && manage-redis start && build-rails-app && $BUILD_STAGE_3"
# Copy artifacts back to /source
rsync -a --delete /builder/vendor/bundle/ /source/vendor/bundle/
rsync -a --delete /builder/public/packs/ /source/public/packs/
EOF
chmod +x docker-entrypoint.sh
git add docker-entrypoint.sh
git commit -m "Add docker-entrypoint.sh for build orchestration" || true
echo "Generated docker-entrypoint.sh"
# Run Docker container
docker run -it --rm -v $(pwd):/source -w /builder -e HOME=/builder --entrypoint /source/docker-entrypoint.sh nixos/nix
