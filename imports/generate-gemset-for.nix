# imports/generate-gemset-for.nix
#
# Script to generate gemset.nix for an external app source.
# Used in orchestrator pattern where gemset.nix lives separate from app source.
#
# Usage:
#   nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/app
#   nix run github:glenndavy/rails-builder#generate-gemset-for -- /path/to/app -o ./apps/my-app/gemset.nix
#
{ pkgs, bundixPackage, defaultRubyPackage }:
''
#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
  echo "Usage: generate-gemset-for <app-source-path> [-o <output-path>]"
  echo ""
  echo "Generate gemset.nix for a Ruby application source directory."
  echo ""
  echo "Arguments:"
  echo "  <app-source-path>  Path to the Ruby application source"
  echo "  -o, --output       Output path for gemset.nix (default: ./gemset.nix)"
  echo ""
  echo "Examples:"
  echo "  generate-gemset-for /path/to/my-rails-app"
  echo "  generate-gemset-for /path/to/my-rails-app -o ./apps/my-app/gemset.nix"
  echo "  generate-gemset-for . -o ../orchestrator/apps/this-app/gemset.nix"
}

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

APP_SOURCE="$1"
shift

OUTPUT_PATH="./gemset.nix"

# Parse optional arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      echo -e "''${RED}Unknown argument: $1''${NC}"
      usage
      exit 1
      ;;
  esac
done

# Validate source path
if [ ! -d "$APP_SOURCE" ]; then
  echo -e "''${RED}Error: App source path does not exist: $APP_SOURCE''${NC}"
  exit 1
fi

if [ ! -f "$APP_SOURCE/Gemfile" ]; then
  echo -e "''${RED}Error: No Gemfile found in $APP_SOURCE''${NC}"
  exit 1
fi

if [ ! -f "$APP_SOURCE/Gemfile.lock" ]; then
  echo -e "''${RED}Error: No Gemfile.lock found in $APP_SOURCE''${NC}"
  echo "Run 'bundle lock' in the app directory first."
  exit 1
fi

# Make paths absolute
APP_SOURCE=$(cd "$APP_SOURCE" && pwd)

# Create output directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
if [ "$OUTPUT_DIR" != "." ] && [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Detect Ruby version from app
RUBY_VERSION=""
if [ -f "$APP_SOURCE/.ruby-version" ]; then
  RUBY_VERSION=$(cat "$APP_SOURCE/.ruby-version" | tr -d '[:space:]')
  echo -e "''${GREEN}Detected Ruby version: $RUBY_VERSION''${NC}"
else
  echo -e "''${YELLOW}Warning: No .ruby-version found, using default Ruby''${NC}"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  Generating gemset.nix                                           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "  Source: $APP_SOURCE"
echo "  Output: $OUTPUT_PATH"
echo ""

# Run bundix with explicit paths
echo "Running bundix..."
${bundixPackage}/bin/bundix \
  --gemfile "$APP_SOURCE/Gemfile" \
  --lockfile "$APP_SOURCE/Gemfile.lock" \
  --gemset "$OUTPUT_PATH"

if [ $? -eq 0 ]; then
  echo ""
  echo -e "''${GREEN}✓ Generated: $OUTPUT_PATH''${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review the generated gemset.nix"
  echo "  2. Commit it to your orchestrator repo"
  echo "  3. Reference it in mkRailsPackage: gemset = ./path/to/gemset.nix;"
else
  echo -e "''${RED}✗ Failed to generate gemset.nix''${NC}"
  exit 1
fi
''
