#!/usr/bin/env bash
# Enhanced version bumping with git tagging for production cache-busting

set -euo pipefail

VERSION_FILE="VERSION"
if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: VERSION file not found"
    exit 1
fi

CURRENT_VERSION=$(cat $VERSION_FILE)
echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
new_patch=$((patch + 1))
NEW_VERSION="$major.$minor.$new_patch"

echo "Bumping version: $CURRENT_VERSION → $NEW_VERSION"

# Update VERSION file
echo "$NEW_VERSION" > $VERSION_FILE

# Update main flake version
sed -i "s/version = \"[^\"]*-auto-bump\"/version = \"$NEW_VERSION-auto-bump\"/" flake.nix

# Update template versions with new scheme
sed -i "s/version = \"[^\"]*-ruby-template\"/version = \"$NEW_VERSION-ruby-template\"/" templates/ruby/flake.nix
sed -i "s/version = \"[^\"]*-rails-template\"/version = \"$NEW_VERSION-rails-template\"/" templates/rails/flake.nix
sed -i "s/version = \"[^\"]*-legacy-bundler\"/version = \"$NEW_VERSION-legacy-bundler\"/" templates/build-rails/flake.nix
sed -i "s/version = \"[^\"]*-legacy-bundix\"/version = \"$NEW_VERSION-legacy-bundix\"/" templates/build-rails-with-nix/flake.nix

# Add current version template alias to main flake
if ! grep -q "ruby-v${NEW_VERSION//./-}" flake.nix; then
    # Add versioned template right after ruby-v2-2-3
    sed -i "/templates\.ruby-v2-2-3 = {/a\\    templates.ruby-v${NEW_VERSION//./-} = {\n      path = ./templates/ruby;\n      description = \"Ruby template v$NEW_VERSION with latest fixes - versioned for cache-busting\";\n    };" flake.nix
fi

echo "Updated all templates to version $NEW_VERSION"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Warning: Not in a git repository. Skipping git operations."
    echo "Manual steps needed:"
    echo "  git add -A"
    echo "  git commit -m 'Release version $NEW_VERSION'"
    echo "  git tag -a v$NEW_VERSION -m 'Release version $NEW_VERSION'"
    echo "  git push && git push --tags"
    exit 0
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Warning: You have uncommitted changes. These will be included in the version bump."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Stage, commit and tag
git add -A

# Create commit message
git commit -m "Release version $NEW_VERSION

- Bump all template versions to $NEW_VERSION
- Add ruby-v${NEW_VERSION//./-} template for cache-busting
- Ensures users get latest fixes without cache issues

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Create annotated tag
git tag -a "v$NEW_VERSION" -m "Release version $NEW_VERSION

Template versions:
- ruby: $NEW_VERSION-ruby-template  
- rails: $NEW_VERSION-rails-template
- build-rails: $NEW_VERSION-legacy-bundler
- build-rails-with-nix: $NEW_VERSION-legacy-bundix

Cache-busting template names:
- ruby-v${NEW_VERSION//./-}

Usage examples:
  nix flake init -t github:glenndavy/rails-builder/v$NEW_VERSION#ruby
  nix flake init -t github:glenndavy/rails-builder#ruby-v${NEW_VERSION//./-}
  nix flake init -t github:glenndavy/rails-builder#ruby --option tarball-ttl 0"

# Push commits and tags
echo "Pushing to origin..."
git push && git push --tags

echo ""
echo "✅ Version $NEW_VERSION released successfully!"
echo ""
echo "🔗 Users can now access the latest templates with:"
echo "   # Versioned (most reliable):"
echo "   nix flake init -t github:glenndavy/rails-builder/v$NEW_VERSION#ruby"
echo ""
echo "   # Cache-busted template name:"
echo "   nix flake init -t github:glenndavy/rails-builder#ruby-v${NEW_VERSION//./-}"
echo ""
echo "   # Latest with cache bypass:"
echo "   nix flake init -t github:glenndavy/rails-builder#ruby --option tarball-ttl 0"
echo ""
echo "📋 GitHub release: https://github.com/glenndavy/rails-builder/releases/tag/v$NEW_VERSION"