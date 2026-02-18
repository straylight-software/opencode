{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          hsPkgs = pkgs.haskellPackages.override {
            overrides = self: super: {
              haskemathesis = self.callPackage ./haskemathesis.nix { };
              opencode-server = self.callPackage ./default.nix { };
            };
          };

          runtimePkgs = with pkgs; [
            ripgrep
            git
            fd
          ];

          server = pkgs.writeShellApplication {
            name = "opencode-server";
            runtimeInputs = runtimePkgs;
            text = ''
              exec ${hsPkgs.opencode-server}/bin/opencode-server "$@"
            '';
          };
        in
        {
          packages = {
            default = server;
            opencode-server = hsPkgs.opencode-server;
          };

          devShells.default = hsPkgs.shellFor {
            packages = p: [ p.opencode-server ];
            buildInputs =
              runtimePkgs
              ++ (with pkgs; [
                cabal-install
                ghcid
                haskell-language-server
              ]);
          };
        };
    };
}
