{
  description = "Rails app in bank-statements";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rails-builder.url = "github:glenndavy/rails-builder";
  };

  outputs = {
    self,
    nixpkgs,
    rails-builder,
  }: let
    system = "x86_64-linux";
    # Define config for insecure packages
    nixpkgsConfig = {
      permittedInsecurePackages = [
        "openssl-1.1.1w"
        "openssl_1_1_1w"
        "openssl-1.1.1"
        "openssl_1_1"
      ];
    };
    # Apply config to pkgs
    pkgs = import nixpkgs {
      inherit system;
      config = nixpkgsConfig;
      overlays = [rails-builder.inputs.nixpkgs-ruby.overlays.default];
    };
    flake_version = "3"; # Incremented to 3
  in {
    packages.${system} = {
      default = rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "vendored";
        nixpkgsConfig = nixpkgsConfig; # Pass config explicitly
      };
      bundix = rails-builder.lib.${system}.buildRailsApp {
        src = ./.;
        gem_strategy = "bundix";
        gemset = import ./gemset.nix;
        nixpkgsConfig = nixpkgsConfig; # Pass config explicitly
      };
      generate-gemset = rails-builder.packages.${system}.generate-gemset;
      # Debug package to inspect openssl and config
      debugOpenssl = pkgs.writeShellScriptBin "debug-openssl" ''
        #!${pkgs.runtimeShell}
        echo "OpenSSL versions available:"
        nix eval --raw nixpkgs#openssl.outPath
        nix eval --raw nixpkgs#openssl_1_1.outPath 2>/dev/null || echo "openssl_1_1 not found"
        echo "Permitted insecure packages:"
        echo "${builtins.concatStringsSep ", " nixpkgsConfig.permittedInsecurePackages}"
        echo "Checking if openssl-1.1.1w is allowed:"
        nix eval --raw nixpkgs#openssl_1_1_1w.outPath 2>/dev/null || echo "openssl-1.1.1w is blocked"
      '';
    };

    devShells.${system}.bundix = rails-builder.devShells.${system}.bundix;

    apps.${system} = {
      detectBundlerVersion = {
        type = "app";
        program = let
          version = rails-builder.lib.${system}.detectBundlerVersion {src = ./.;};
          script = pkgs.writeScriptBin "detect-bundler-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-bundler-version";
      };

      detectRubyVersion = {
        type = "app";
        program = let
          version = (rails-builder.lib.${system}.detectRubyVersion {src = ./.;}).dotted;
          script = pkgs.writeScriptBin "detect-ruby-version" ''
            #!${pkgs.runtimeShell}
            echo "${version}"
          '';
        in "${script}/bin/detect-ruby-version";
      };

      flakeVersion = {
        type = "app";
        program = "${pkgs.writeScriptBin "flake-version" ''
          #!${pkgs.runtimeShell}
          echo "${flake_version}"
        ''}/bin/flake-version";
      };
    };
  };
}
