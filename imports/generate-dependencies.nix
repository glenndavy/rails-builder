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
  # Remove bundled stdlib gems causing nil errors
  sed -i '/"net-pop"/,/^    };/d' gemset.nix
  sed -i '/"matrix"/,/^    };/d' gemset.nix
  # Add more sed for other bundled if needed (e.g., net-smtp, prime from Ruby 3.2 list)
  if [ -f yarn.lock ]; then
    echo "Computing Yarn hash..."
    YARN_HASH=$(${pkgs.prefetch-yarn-deps}/bin/prefetch-yarn-deps yarn.lock | grep sha256 | cut -d '"' -f2)
    echo "Yarn hash (for fetchYarnDeps sha256): $YARN_HASH"
  fi
  git add gemset.nix
  echo "Done."
''
