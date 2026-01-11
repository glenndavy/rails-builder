{
  pkgs,
  rubyPackage,
  bundlerVersion,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "Generating gemset.nix from Gemfile.lock..."
  export PATH=${rubyPackage}/bin:${pkgs.nix-prefetch-scripts}/bin:${pkgs.bundix}/bin:$PATH
  echo "Verifying Ruby version: $(${rubyPackage}/bin/ruby -v)"
  export GEM_HOME=$(mktemp -d)
  ${rubyPackage}/bin/gem install bundler --version ${bundlerVersion} --no-document
  export PATH=$GEM_HOME/bin:$PATH
  bundix --magic -l
  ## Remove invalid entries if errors persist
  #awk '
  #  BEGIN { RS = "}"; ORS = "}"; printing = 1 }
  #  /sha256 = ""/ || /sha256 = nil/ { printing = 0; next }
  #  printing { print $0 }
  #  { printing = 1 }
  #' gemset.nix > gemset-clean.nix
  #mv gemset-clean.nix gemset.nix
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock | grep sha256 | cut -d '"' -f2)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
  fi
  git add gemset.nix
  echo "Done."
''
