{pkgs}: ''
  #!${pkgs.runtimeShell}
  echo "Generating prefetch files..."
  nix-shell -p bundix --run "bundix --magic"  # Or bundix -l for lock
  if [ -f yarn.lock ]; then
    nix-shell -p yarn2nix --run "yarn2nix --lockfile=yarn.lock > yarn.nix"
  fi
  git add gemset.nix yarn.nix
  echo "Done. Commit if changed."
''
