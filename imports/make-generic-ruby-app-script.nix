{
  pkgs,
  rubyPackage,
  bundlerPackage,
  bundlerVersion,
  rubyMajorMinor,
  framework ? "ruby",
}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "DEBUG: Starting build-${framework}-app" >&2
  export HOME=$PWD
  export source=$PWD
  
  # Generic Ruby environment (not Rails-specific)
  export APP_ROOT=$PWD
  export BUNDLE_PATH=$APP_ROOT/vendor/bundle
  export BUNDLE_GEMFILE=$PWD/Gemfile
  export PATH=$BUNDLE_PATH/bin:$APP_ROOT/bin:${bundlerPackage}/bin:${rubyPackage}/bin:$PATH
  
  # Framework-specific environment
  ${if framework == "rails" then ''
    export RAILS_ROOT=$PWD
    export RAILS_ENV=production  
    export SECRET_KEY_BASE=dummy_value_for_build
  '' else if framework == "hanami" then ''
    export HANAMI_ENV=production
  '' else if framework == "rack" then ''
    export RACK_ENV=production
  '' else ''
    export RUBY_ENV=production
  ''}
  
  echo "DEBUG: BUNDLE_PATH=$BUNDLE_PATH" >&2
  echo "DEBUG: BUNDLE_GEMFILE=$BUNDLE_GEMFILE" >&2
  echo "DEBUG: Framework: ${framework}" >&2
  echo "DEBUG: Ruby version: $(${rubyPackage}/bin/ruby -v)" >&2
  
  echo "DEBUG: Installing Bundler ${bundlerVersion}" >&2
  ${rubyPackage}/bin/gem install bundler:${bundlerVersion} --no-document -i vendor/bundle/ruby/${rubyMajorMinor}.0
  
  echo "DEBUG: Running bundle install..." >&2
  if ! ${bundlerPackage}/bin/bundle install --standalone --path $BUNDLE_PATH --binstubs; then
    echo "ERROR: bundle install failed" >&2
    exit 1
  fi
  
  # Add common files to git (if git repo exists)
  git add .ruby-version 2>/dev/null || true
  git add -f $APP_ROOT/bin 2>/dev/null || true
  
  # Framework-specific build steps
  ${if framework == "rails" then ''
    echo "DEBUG: Running Rails asset precompilation..." >&2
    git add -f ./public 2>/dev/null || true
    ${bundlerPackage}/bin/bundle exec rake assets:precompile
  '' else if framework == "hanami" then ''
    echo "DEBUG: Running Hanami asset compilation..." >&2
    git add -f ./public 2>/dev/null || true
    # Hanami 2.x uses hanami assets compile, 1.x uses hanami assets precompile
    if ${bundlerPackage}/bin/bundle exec hanami version | grep -q "^2\."; then
      ${bundlerPackage}/bin/bundle exec hanami assets compile 2>/dev/null || echo "No assets to compile"
    else
      ${bundlerPackage}/bin/bundle exec hanami assets precompile 2>/dev/null || echo "No assets to precompile"  
    fi
  '' else if framework == "rack" then ''
    echo "DEBUG: Rack app detected, checking for asset compilation..." >&2
    # Check for common asset compilation tasks
    if [ -f "package.json" ] && [ -f "webpack.config.js" ]; then
      echo "DEBUG: Found webpack, running npm run build..." >&2
      npm run build 2>/dev/null || echo "npm build failed or not configured"
    elif ${bundlerPackage}/bin/bundle exec rake -T 2>/dev/null | grep -q "assets:"; then
      echo "DEBUG: Found assets rake tasks, running..." >&2
      ${bundlerPackage}/bin/bundle exec rake assets:precompile 2>/dev/null || echo "Asset compilation failed"
    else
      echo "DEBUG: No asset compilation needed for this Rack app" >&2
    fi
    git add -f ./public 2>/dev/null || true
  '' else ''
    echo "DEBUG: Generic Ruby app, no asset compilation" >&2
    # For plain Ruby apps, just ensure dependencies are ready
    if [ -f "Rakefile" ]; then
      echo "DEBUG: Found Rakefile, checking for build tasks..." >&2
      if ${bundlerPackage}/bin/bundle exec rake -T 2>/dev/null | grep -q "build\|compile"; then
        ${bundlerPackage}/bin/bundle exec rake build 2>/dev/null || echo "Build task failed or not available"
      fi
    fi
  ''}
  
  echo "Build complete for ${framework} app in $(pwd)" >&2
  echo "DEBUG: build-${framework}-app completed" >&2
''