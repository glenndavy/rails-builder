#!/usr/bin/env bash
# Automatic version bumping script for cache busting

VERSION_FILE="VERSION"
CURRENT_VERSION=$(cat $VERSION_FILE)

# Parse version components
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

# Increment patch version
new_patch=$((patch + 1))
NEW_VERSION="$major.$minor.$new_patch"

echo "Bumping version: $CURRENT_VERSION → $NEW_VERSION"

# Update VERSION file
echo "$NEW_VERSION" > $VERSION_FILE

# Update all template versions
sed -i "s/version = \"[^\"]*\"/version = \"$NEW_VERSION-auto-bump\"/" flake.nix
sed -i "s/version = \"[^\"]*\"/version = \"$NEW_VERSION-ruby-template\"/" templates/ruby/flake.nix
sed -i "s/version = \"[^\"]*\"/version = \"$NEW_VERSION-rails-template\"/" templates/rails/flake.nix
sed -i "s/version = \"[^\"]*\"/version = \"$NEW_VERSION-legacy-bundler\"/" templates/build-rails/flake.nix
sed -i "s/version = \"[^\"]*\"/version = \"$NEW_VERSION-legacy-bundix\"/" templates/build-rails-with-nix/flake.nix

echo "Updated all templates to version $NEW_VERSION"
echo "Ready to commit with: git add -A && git commit -m 'Auto-bump version to $NEW_VERSION' && git push"