{
     description = "Rails app builder flake";

     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
       nixpkgs-ruby.url = "github:bobvanderlinden/nixpkgs-ruby";
     };

     outputs = { self, nixpkgs, nixpkgs-ruby }: let
       forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system: f system);
     in {
       lib = {
         buildRailsApp = { system, rubyVersion, src, gems }: 
           let
             needsInsecureOpenSSL = let
               versionParts = builtins.splitVersion (builtins.replaceStrings ["_"] ["."] rubyVersion);
               major = builtins.elemAt versionParts 0;
               minor = builtins.elemAt versionParts 1;
             in (major == "2" || (major == "3" && minor == "0") || (major == "3" && minor == "1"));
             pkgs = import nixpkgs {
               inherit system;
               overlays = [ nixpkgs-ruby.overlays.default ];
               config = {
                 permittedInsecurePackages = nixpkgs.lib.optionals needsInsecureOpenSSL [ "openssl-1.1.1w" ];
               };
             };
             rubyVersionDotted = builtins.replaceStrings ["_"] ["."] rubyVersion;
             ruby = pkgs."ruby-${rubyVersionDotted}";
           in
             pkgs.stdenv.mkDerivation {
               name = "rails-app";
               inherit src;
               buildInputs = [ ruby ];
               buildPhase = ''
               echo "***** BUILDER VERSION 0.1 *******************"
              # Isolate all gem-related paths
                 export HOME=$TMPDIR
                 export GEM_HOME=$TMPDIR/gems
                 export GEM_PATH=$GEM_HOME
                 export BUNDLE_PATH=$TMPDIR/vendor/bundle
                 export BUNDLE_USER_HOME=$TMPDIR/.bundle
                 export BUNDLE_USER_CACHE=$TMPDIR/.bundle/cache
                 mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $BUNDLE_USER_HOME $BUNDLE_USER_CACHE
            # Configure Bundler
                 bundle config set --local path 'vendor/bundle'
                 bundle config set --local gemfile Gemfile
                 bundle install --verbose
                 rails assets:precompile
              '';
              installPhase = ''
                mkdir -p $out
                cp -r . $out
                '';
             };

         nixosModule = { railsApp, ... }: {
           imports = [ ./nixos-module.nix ];
           config.deployment.railsApp = railsApp;
         };

         dockerImage = { system, railsApp }: 
           let
             pkgs = import nixpkgs { inherit system; };
           in
           pkgs.dockerTools.buildImage {
             name = "rails-app";
             tag = "latest";
             contents = [ railsApp ];
             config = {
               Cmd = [ "${railsApp}/bin/bundle" "exec" "puma" "-C" "config/puma.rb" ];
               ExposedPorts = { "3000/tcp" = {}; };
             };
           };
       };
     };
   }
