#!/bin/sh
set -e

# Validate input
if [ -z "$1" ]; then
  echo "Error: Repository URL required"
  exit 1
fi
REPO_URL="$1"
BUILD_TYPE="${2:-docker}" # Default to docker if not specified

# Set build stage
case "$BUILD_TYPE" in
  docker)
    export BUILD_STAGE_3="nix build .#dockerImage"
    ;;
  nix)
    export BUILD_STAGE_3="nix build .#buildApp"
    ;;
  *)
    echo "Error: Invalid build type. Use 'docker' or 'nix'"
    exit 1
    ;;
esac

# Clone repository
REPO_DIR=$(basename "$REPO_URL" .git)
git clone --depth 1 "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# Download and run build-stage-02.sh
curl -s -o build-stage-02.sh https://raw.githubusercontent.com/glenndavy/rails-builder/main/scripts/build-stage-02.sh
chmod +x build-stage-02.sh
./build-stage-02.sh
