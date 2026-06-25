# Framework detection for Ruby applications
{src}: let
  hasFile = file: builtins.pathExists (src + "/${file}");
  
  # Check if gem is present in Gemfile.lock
  hasGem = gemName: 
    if hasFile "Gemfile.lock" 
    then let
      content = builtins.readFile (src + "/Gemfile.lock");
      # Look for gem name at start of line (more precise than regex)
      lines = builtins.split "\n" content;
      hasGemLine = builtins.any (line: 
        if builtins.isString line 
        then let
          trimmedLine = builtins.replaceStrings [" " "\t"] ["" ""] line;
        in builtins.substring 0 (builtins.stringLength gemName) trimmedLine == gemName
        else false
      ) lines;
    in hasGemLine
    else false;
    
  # Check Gemfile content for specific gems (fallback)
  gemfileContains = gemName:
    if hasFile "Gemfile"
    then let 
      content = builtins.readFile (src + "/Gemfile");
    in builtins.match ".*gem.*['\"]${gemName}['\"].*" content != null
    else false;

  # Database detection based on actual gems
  databaseGems = {
    postgresql = hasGem "pg";
    mysql = hasGem "mysql2";
    sqlite = hasGem "sqlite3";
  };
  
  # Cache/session store detection
  cacheGems = {
    redis = hasGem "redis" || hasGem "redis-rails" || hasGem "redis-store";
    memcached = hasGem "memcached" || hasGem "dalli";
  };

  # Background job processing detection
  backgroundJobGems = {
    sidekiq = hasGem "sidekiq";
    resque = hasGem "resque";
    good_job = hasGem "good_job";
    solid_queue = hasGem "solid_queue";
    delayed_job = hasGem "delayed_job_active_record" || hasGem "delayed_job";
  };

  # Image processing detection
  imageGems = {
    vips = hasGem "ruby-vips" || hasGem "image_processing";
    imagemagick = hasGem "mini_magick" || hasGem "rmagick";
    libvips = hasGem "ruby-vips" || (hasGem "image_processing" && hasGem "ruby-vips");
    cairo = hasGem "cairo";
  };

  # Testing/browser automation detection
  testingGems = {
    selenium = hasGem "selenium-webdriver";
    capybara = hasGem "capybara";
    playwright = hasGem "playwright-ruby";
    chromedriver = hasGem "webdrivers" || hasGem "chromedriver-helper";
  };
  
  # Asset-related gems detection
  assetGems = {
    sprockets = hasGem "sprockets" || hasGem "sprockets-rails";
    webpacker = hasGem "webpacker";
    shakapacker = hasGem "shakapacker";
    esbuild = hasGem "esbuild-rails";
    vite = hasGem "vite_rails";
    propshaft = hasGem "propshaft";
    tailwindcss = hasGem "tailwindcss-rails" || hasGem "tailwindcss-ruby";
  };

  hasHanamiGem = hasGem "hanami" || gemfileContains "hanami";
  # Hanami 2.x has config/app.rb (introduced in 2.0). Hanami 1.x doesn't —
  # it uses config/environment.rb (+ apps/<name>/application.rb directory
  # layout). Rails also has config/environment.rb so we order-check rails
  # first below; if we got past rails, config/environment.rb + hanami gem
  # identifies a 1.x app.
  isHanami2 = hasFile "config/app.rb" && hasHanamiGem;
  isHanami1 =
    !isHanami2
    && hasHanamiGem
    && (hasFile "config/environment.rb" || hasFile "apps");

in {
  # Framework detection logic. Rails is checked first because its
  # config/environment.rb file would otherwise also match Hanami 1.x.
  framework =
    if hasFile "config/application.rb" && (hasGem "rails" || gemfileContains "rails") then "rails"
    else if isHanami2 || isHanami1 then "hanami"
    else if hasFile "config.ru" && (hasGem "sinatra" || gemfileContains "sinatra") then "sinatra"
    else if hasFile "config.ru" then "rack"
    else if hasFile "Rakefile" then "ruby-with-rake"
    else "ruby";

  # Major version of Hanami when detected, else null. Downstream scripts
  # branch on this for the right `hanami assets` command (compile vs
  # precompile) and for app-name parsing (config/app.rb vs lib/<name>.rb).
  hanamiVersion =
    if isHanami2 then 2
    else if isHanami1 then 1
    else null;
    
  # Determine if assets need compilation (based on actual gems)
  hasAssets = 
    assetGems.sprockets || assetGems.webpacker || assetGems.shakapacker || 
    assetGems.esbuild || assetGems.vite || assetGems.propshaft ||
    hasFile "package.json" || hasFile "webpack.config.js" || hasFile "vite.config.js";
    
  # Determine entry point
  entryPoint = 
    if hasFile "config.ru" then "config.ru"
    else if hasFile "bin/rails" then "bin/rails"
    else if hasFile "exe/${builtins.baseNameOf (toString src)}" then "exe/${builtins.baseNameOf (toString src)}"
    else null;
    
  # Determine if it's a web application
  isWebApp = hasFile "config.ru" || hasFile "config/application.rb";
  
  # Database requirements (based on gems, not framework)
  needsPostgresql = databaseGems.postgresql;
  needsMysql = databaseGems.mysql;
  needsSqlite = databaseGems.sqlite;
  
  # Cache/session store requirements
  needsRedis = cacheGems.redis || backgroundJobGems.sidekiq || backgroundJobGems.resque;
  needsMemcached = cacheGems.memcached;

  # Background job requirements
  needsBackgroundJobs = backgroundJobGems.sidekiq || backgroundJobGems.resque || backgroundJobGems.good_job || backgroundJobGems.solid_queue || backgroundJobGems.delayed_job;

  # Image processing requirements
  needsImageMagick = imageGems.imagemagick;
  needsLibVips = imageGems.vips || imageGems.libvips;
  needsCairo = imageGems.cairo;

  # Browser testing requirements
  needsBrowserDrivers = testingGems.selenium || testingGems.capybara || testingGems.playwright;

  # Tailwindcss requirement (needs external binary for bundlerEnv builds)
  needsTailwindcss = assetGems.tailwindcss;

  # Combined database support needed
  needsDatabase = databaseGems.postgresql || databaseGems.mysql || databaseGems.sqlite;
  
  # Asset compilation details
  assetPipeline = 
    if assetGems.sprockets then "sprockets"
    else if assetGems.webpacker then "webpacker"
    else if assetGems.shakapacker then "shakapacker"
    else if assetGems.esbuild then "esbuild"
    else if assetGems.vite then "vite"
    else if assetGems.propshaft then "propshaft"
    else if hasFile "webpack.config.js" then "webpack"
    else if hasFile "vite.config.js" then "vite"
    else null;
}