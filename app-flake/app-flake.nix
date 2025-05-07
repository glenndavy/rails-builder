{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    railsBuilder.url = "github:glenndavy/rails-builder";
  };

  outputs = { self, nixpkgs, railsBuilder }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages.${system}.default = railsBuilder.lib.buildRailsApp {
      pkgs = railsBuilder.pkgsFor.${system};
      src = ./.;
      gem_strategy = "vendored";
    };
  };
}
