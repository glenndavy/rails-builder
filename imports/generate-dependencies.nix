{
  pkgs,
  rubyPackage,
  bundlerVersion,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "Generating gemset.nix from Gemfile.lock..."
  export PATH=${rubyPackage}/bin:${pkgs.nix-prefetch-scripts}/bin:$PATH
  echo "Verifying Ruby version: $(${rubyPackage}/bin/ruby -v)"
  export GEM_HOME=$(mktemp -d)
  ${rubyPackage}/bin/gem install bundler --version ${bundlerVersion} --no-document
  ${rubyPackage}/bin/gem install bundix --no-document
  export PATH=$GEM_HOME/bin:$PATH
  bundix -l
  nix --impure eval --expr 'with import <nixpkgs> {}; let gemset = import ./gemset.nix; filtered = builtins.filterAttrs (n: v: (v.source or {} ? sha256) && v.source.sha256 != "" && v.source.sha256 != null) gemset; in lib.generators.toPretty {} filtered' > gemset-clean.nix
  mv gemset-clean.nix gemset.nix
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock | grep sha256 | cut -d '"' -f2)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
  fi
  git add gemset.nix
  echo "Done."
''
