{ inputs, lib, ... }:
{
  imports = [ inputs.haskell-flake.flakeModule ];

  perSystem =
    { self', pkgs, ... }:
    let
      runtimePkgs = with pkgs; [
        ripgrep
        git
        fd
      ];

      withRuntimeDeps = pkgs.writeShellApplication {
        name = "opencode-server";
        runtimeInputs = runtimePkgs;
        text = ''
          exec ${lib.getExe self'.packages.opencode-server}
        '';
      };
    in
    {
      haskellProjects.default = {
        packages = {
          haskemathesis.source = inputs.haskemathesis;
        };
        settings = {
          opencode-server = {
            stan = true;
            extraTestToolDepends = runtimePkgs;
          };
          librarySystemDepends = [ pkgs.zlib ];
        };
        devShell = {
          tools = hp: {
            cabal = hp.cabal-install;
          };
          mkShellArgs = {
            buildInputs = runtimePkgs;
          };
        };
      };

      packages.default = withRuntimeDeps;
      checks.default = withRuntimeDeps;
    };
}
