{
  pkgs,
  rubyPackage,
  bundlerVersion,
  rubyMajorMinor,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  export HOME=$PWD
  export source=$PWD
  export RAILS_ROOT=$PWD
  export BUNDLE_PATH=$RAILS_ROOT/vendor/bundle
  export BUNDLE_GEMFILE=$PWD/Gemfile
  export PATH=$BUNDLE_PATH/bin:$RAILS_ROOT/bin:${rubyPackage}/bin:$PATH
  export RAILS_ENV=production
  export SECRET_KEY_BASE=dummy_value_for_build

  echo "Installing Bundler ${bundlerVersion}..."
  ${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document -i vendor/bundle/ruby/${rubyMajorMinor}.0

  echo "Running bundle install..."
  # Use --deployment instead of --standalone so that bundle exec works interactively
  # --deployment: installs to vendor/bundle with proper bundler metadata
  # --standalone: creates setup.rb for bundler-less runtime but breaks bundle exec
  if ! ${rubyPackage}/bin/bundle install --deployment --path $BUNDLE_PATH --binstubs; then
    echo "ERROR: bundle install failed" >&2
    exit 1
  fi

  git add .ruby-version ||true
  git add -f $RAILS_ROOT/bin
  git add -f ./public
  git add -f $BUNDLE_PATH

  echo "Running asset precompilation..."
  ${rubyPackage}/bin/bundle exec rake assets:precompile

  echo "Build complete. Outputs in $BUNDLE_PATH, public/packs."
''
