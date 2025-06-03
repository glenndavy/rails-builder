#!/bin/sh
set -e

# Validate input
if [ -z "$1" ]; then
  echo "Error: Repository URL required" >&2
  exit 1
fi
REPO_URL="$1"
BUILD_TYPE="${2:-docker}" # Default to docker

# Set build stage
case "$BUILD_TYPE" in
  docker)
    BUILD_STAGE_3="nix build .#dockerImage"
    ;;
  nix)
    BUILD_STAGE_3="nix build .#buildApp"
    ;;
  *)
    echo "Error: Invalid build type. Use 'docker' or 'nix'" >&2
    exit 1
    ;;
esac
export BUILD_STAGE_3

# Clone repository
REPO_DIR=$(basename "$REPO_URL" .git)
git clone --depth 1 "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# Run build-stage-02.sh from scripts/
if [ ! -f scripts/build-stage-02.sh ]; then
  # Attempt to download from rails-builder
  SCRIPT_URL="https://raw.githubusercontent.com/glenndavy/rails-builder/main/scripts/build-stage-02.sh"
  if ! curl -s -o scripts/build-stage-02.sh -f "$SCRIPT_URL"; then
    echo "Error: Failed to download build-stage-02.sh from $SCRIPT_URL" >&2
    exit 1
  fi
  if ! grep -q '^#!/bin/sh' scripts/build-stage-02.sh; then
    echo "Error: Downloaded build-stage-02.sh is invalid (not a shell script)" >&2
    cat scripts/build-stage-02.sh
    exit 1
  fi
fi
chmod +x scripts/build-stage-02.sh
scripts/build-stage-02.sh
