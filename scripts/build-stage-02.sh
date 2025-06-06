#!/bin/sh
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
echo "DEBUG: Starting docker-entrypoint.sh" >&2
# Configure nix.conf for download-buffer-size
mkdir -p /etc/nix
echo "download-buffer-size = 20971520" >> /etc/nix/nix.conf
# Set up /builder and ownership
mkdir -p /builder
chown root:root /builder
export HOME=/builder
# Explicitly copy critical files
for file in /source/flake.nix /source/.ruby-version /source/.gitignore /source/Gemfile /source/Gemfile.lock; do
  if [ -f "$file" ]; then
    cp "$file" /builder/
  else
    echo "Warning: $file not found in /source" >&2
  fi
done
# Copy all files, excluding .git
for item in /source/* /source/.*; do
  if [ -e "$item" ] && [ "$(basename "$item")" != "." ] && [ "$(basename "$item")" != ".." ] && [ "$(basename "$item")" != ".git" ]; then
    cp -r "$item" /builder/ 2>/dev/null || true
  fi
done
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
# Run commands in buildShell, including rsync
nix run .#flakeVersion --extra-experimental-features 'nix-command flakes'
echo "about to run nix develop"
echo "DEBUG: BUILD_STAGE_3=$BUILD_STAGE_3" >&2
echo "DEBUG: sh -c command: manage-postgres start && manage-redis start && build-rails-app $BUILD_STAGE_3 && rsync -a --delete /builder/vendor/bundle/ /source/vendor/bundle/ && [ -d /builder/public/packs ] && rsync -a --delete /builder/public/packs/ /source/public/packs/ || true" >&2
nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && manage-redis start && build-rails-app $BUILD_STAGE_3 && rsync -a --delete /builder/vendor/bundle/ /source/vendor/bundle/ && [ -d /builder/public/packs ] && rsync -a --delete /builder/public/packs/ /source/public/packs/ || true"
echo "DEBUG: docker-entrypoint.sh completed" >&2
EOF
chmod +x docker-entrypoint.sh
git add docker-entrypoint.sh
git commit -m "Add docker-entrypoint.sh for build orchestration" || true
echo "Generated docker-entrypoint.sh"
# Ensure Nix store volume exists
docker volume create nix-store || true
# Run Docker container with Nix store volume
docker run -it --rm -v $(pwd):/source -v nix-store:/nix/store -w /builder -e HOME=/builder --entrypoint /source/docker-entrypoint.sh nixos/nix
