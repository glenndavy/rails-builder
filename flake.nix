{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Existing buildRailsApp function (simplified)
    buildRailsApp = { ruby, gemset ? null, src, buildInputs ? [], BUNDLE_PATH ? null }:
      pkgs.stdenv.mkDerivation {
        name = "rails-app";
        inherit src buildInputs;
        nativeBuildInputs = [ ruby ] ++ (if gemset != null then [ ruby.gems ] else []);
        buildPhase = ''
          ${if gemset != null then ''
            # Use gemset.nix for gems
            bundle config set --local path $out/gems
            bundle install
          '' else ''
            # Use vendored gems
            ${if BUNDLE_PATH != null then ''
              bundle config set --local path ${BUNDLE_PATH}
              bundle install
            '' else ''
              bundle install
            ''}
          ''}
        '';
        installPhase = ''
          mkdir -p $out
          cp -r . $out
        '';
      };
  in
  {
    lib.buildRailsApp = buildRailsApp;

    # Utility scripts
    packages.${system}.generate-gemset = pkgs.writeFile {
      name = "generate-gemset";
      executable = true;
      destination = "/bin/generate-gemset";
      text = ''
        #!/bin/bash
        if [ ! -f Gemfile.lock ]; then
          echo "Error: Gemfile.lock is missing."
          exit 1
        fi
        if [ ! -d vendor/cache ]; then
          echo "Error: vendor/cache is missing."
          exit 1
        fi
        ${pkgs.bundix}/bin/bundix --local
        if [ ! -f gemset.nix ]; then
          echo "Error: Failed to generate gemset.nix."
          exit 1
        fi
        echo "Generated gemset.nix successfully."
      '';
    };

    # Shell environment for running bundix
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ pkgs.bundix ];
      shellHook = ''
        echo "Run 'bundix --local' to generate gemset.nix, or use 'nix run .#generate-gemset'."
      '';
    };
  };
}
