{
  pkgs,
  rubyPackage,
  bundlerVersion,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "Generating gemset.nix with Bundler ${bundlerVersion} on Ruby ${rubyPackage.version}..."
  export PATH=${rubyPackage}/bin:$PATH
  export GEM_HOME=$(mktemp -d)
  gem install bundler --version ${bundlerVersion} --no-document
  bundle install --path vendor/bundle --standalone
  ${pkgs.bundix}/bin/bundix --magic  # Or bundix -l for lock-only
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
    # Optionally sed into flake.nix: sed -i "s|sha256 = \".*\";|sha256 = \"$YARN_HASH\";|" flake.nix
  fi
  git add gemset.nix  # Add yarn.hash if saving separately
  echo "Done."
''
