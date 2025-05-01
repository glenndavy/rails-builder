{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = fn:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ] (system: fn system);
  in
    forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      packages.${system} = {
        hello-world = pkgs.writeText "hello-world" "Hello, world!";
        goodbye-world = pkgs.writeText "goodbye-world" "Goodbye, world!";
      };
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [pkgs.neovim];
        shellHook = ''
          echo "Welcome to the devShell with Neovim!"
          nvim --version
        '';
      };
    });
}
