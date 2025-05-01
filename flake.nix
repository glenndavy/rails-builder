{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    packages.${system} = {
      hello-world = pkgs.writeFile {
        name = "hello-world";
        text = "Hello, world!";
      };
      goodbye-world = pkgs.writeFile {
        name = "goodbye-world";
        text = "Goodbye, world!";
      };
    };
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [pkgs.neovim];
      shellHook = ''
        echo "Welcome to the devShell with Neovim!"
        nvim --version
      '';
    };
  };
}
