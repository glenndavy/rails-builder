{pkgs}: ''
  #!${pkgs.runtimeShell}
  echo "Generating prefetch files..."
  nix-shell -p bundix --run "bundix --magic"  # Or bundix -l for lock
  git add gemset.nix
  echo "Computing Yarn hash..."
  YARN_HASH=$(nix run nixpkgs#prefetch-yarn-deps -- yarn.lock | grep sha256 | sed -E 's/.*"([^"]+)".*/\1/')
  echo "Updating Nix expr with sha256=$YARN_HASH"
  sed -i "s|sha256 = \".*\";|sha256 = \"$YARN_HASH\";|" flake.nix  # Adjust path/pattern as needed
  echo "DONE"
''
