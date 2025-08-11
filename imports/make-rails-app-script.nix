{
  pkgs,
  rubyPackage,
  bundlerVersion,
  rubyMajorMinor,
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "DEBUG: Starting build-rails-app" >&2
  export HOME=$PWD
  export source=$PWD
  export RAILS_ROOT=$PWD
  export BUNDLE_PATH=$RAILS_ROOT/vendor/bundle
  export BUNDLE_GEMFILE=$PWD/Gemfile
  export PATH=$BUNDLE_PATH/bin:$RAILS_ROOT/bin:${rubyPackage}/bin:$PATH
  export RAILS_ENV=production
  export SECRET_KEY_BASE=dummy_value_for_build
  echo "DEBUG: BUNDLE_PATH=$BUNDLE_PATH" >&2
  echo "DEBUG: BUNDLE_GEMFILE=$BUNDLE_GEMFILE" >&2
  echo "DEBUG: PATH=$PATH" >&2
  echo "DEBUG: source=$source" >&2
  echo "DEBUG: Gemfile exists: $([ -f "$BUNDLE_GEMFILE" ] && echo 'yes' || echo 'no')" >&2
  echo "DEBUG: Ruby version: $(${rubyPackage}/bin/ruby -v)" >&2
  echo "DEBUG: Installing Bundler ${bundlerVersion}" >&2
  ${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document -i vendor/bundle/ruby/${rubyMajorMinor}.0
  echo "DEBUG: Bundler version: $(${rubyPackage}/bin/bundle -v)" >&2
  echo "DEBUG: Running bundle install..." >&2
  if ! ${rubyPackage}/bin/bundle install --standalone --path $BUNDLE_PATH --binstubs; then
    echo "ERROR: bundle install failed" >&2
    exit 1
  fi
  git add .ruby-version ||true
  git add -f $RAILS_ROOT/bin
  git add -f ./public
  git add -f $BUNDLE_PATH
  echo "DEBUG: Running rake assets:precompile..." >&2
  ${rubyPackage}/bin/bundle exec rake assets:precompile
  echo "Build complete. Outputs in $BUNDLE_PATH, public/packs." >&2
  echo "DEBUG: build-rails-app in $(pwd) completed" >&2
''
