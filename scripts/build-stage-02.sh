#!/bin/bash
set -e

# Validate BUILD_STAGE_3
if [ -z "$BUILD_STAGE_3" ]; then
  echo "Error: BUILD_STAGE_3 not set"
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
cat <<'EOF' > docker-entrypoint.sh
#!/bin/sh
set -e
mkdir -p /builder
cp -r /source/* /builder/
cd /builder
# Start services
manage-postgres start
manage-redis start
# Execute command
exec "$@"
EOF
chmod +x docker-entrypoint.sh

# Run Docker container
docker run -it --rm -v $(pwd):/source -w /builder -e HOME=/builder --entrypoint /source/docker-entrypoint.sh nixos/nix \
  nix develop .#buildShell --extra-experimental-features 'nix-command flakes' --command bash -c "build-rails-app && $BUILD_STAGE_3"
