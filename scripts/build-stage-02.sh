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
  nix flake lock
fi

# Generate docker-entrypoint.sh using here-document
cat <<'EOF' > scripts/docker-entrypoint.sh
#!/bin/sh
set -e
mkdir -p /builder
cp -r /source/* /builder/
cd /builder
# Run commands in buildShell
nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command sh -c "manage-postgres start && manage-redis start && build-rails-app && $BUILD_STAGE_3"
# Copy artifacts back to /source
rsync -a --delete /builder/vendor/bundle/ /source/vendor/bundle/
rsync -a --delete /builder/public/packs/ /source/public/packs/
EOF
chmod +x scripts/docker-entrypoint.sh

# Run Docker container
docker run -it --rm -v $(pwd):/source -w /builder -e HOME=/builder --entrypoint /source/scripts/docker-entrypoint.sh nixos/nix
