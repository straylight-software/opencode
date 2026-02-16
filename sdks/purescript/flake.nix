{
  description = ''
    weapon-purescript — PureScript SDK for Weapon AI coding agent

    Generated types from OpenAPI via zeitschrift.
    WebSocket client for real-time event streaming.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    purescript-overlay.url = "github:thomashoneyman/purescript-overlay";
    zeitschrift.url = "path:/home/b7r6/src/weyl/zeitschrift";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      purescript-overlay,
      zeitschrift,
      ...
    }:
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
          # Apply purescript overlay for latest tooling
          pkgsWithPS = import nixpkgs {
            inherit system;
            overlays = [ purescript-overlay.overlays.default ];
          };

          # Zeitschrift for OpenAPI codegen
          zeitschriftPkg = zeitschrift.packages.${system}.default;

          # PureScript toolchain
          pursTools = with pkgsWithPS; [
            purs
            spago-unstable
            purs-tidy
            purs-backend-es
          ];

          # Path to openapi spec (relative to repo root)
          openapiSpec = ../../packages/openapi/openapi.json;
        in
        {
          packages = {
            default = pkgsWithPS.stdenv.mkDerivation {
              pname = "weapon-purescript";
              version = "0.1.0";
              src = ./.;

              nativeBuildInputs = pursTools ++ [ pkgsWithPS.esbuild ];

              buildPhase = ''
                export HOME=$TMPDIR
                spago build
              '';

              installPhase = ''
                mkdir -p $out
                cp -r output $out/
                cp -r src $out/
              '';
            };

            # Generate types from OpenAPI
            generate-types = pkgsWithPS.writeShellScriptBin "generate-types" ''
              set -euo pipefail
              echo "Generating PureScript types from OpenAPI spec..."
              ${zeitschriftPkg}/bin/zeitschrift codegen \
                --lang purescript \
                --input ${openapiSpec} \
                --output src/Weapon/Generated
              echo "Done! Types written to src/Weapon/Generated/"
            '';
          };

          apps = {
            default = {
              type = "app";
              program = "${pkgsWithPS.writeShellScriptBin "weapon-ps-demo" ''
                cd ${./.}
                ${pkgsWithPS.spago-unstable}/bin/spago run
              ''}/bin/weapon-ps-demo";
            };

            generate = {
              type = "app";
              program = "${pkgsWithPS.writeShellScriptBin "generate" ''
                set -euo pipefail
                cd "$(dirname "$0")/../.."
                echo "Generating PureScript types from OpenAPI spec..."
                ${zeitschriftPkg}/bin/zeitschrift codegen \
                  --lang purescript \
                  --input packages/openapi/openapi.json \
                  --output sdks/purescript/src/Weapon/Generated
                echo "Done!"
              ''}/bin/generate";
            };
          };

          devShells.default = pkgsWithPS.mkShell {
            buildInputs = pursTools ++ [
              zeitschriftPkg
              pkgsWithPS.nodejs
              pkgsWithPS.esbuild
            ];

            shellHook = ''
              echo ""
              echo "  ╔═══════════════════════════════════════════════════════════╗"
              echo "  ║              weapon-purescript SDK                        ║"
              echo "  ║                                                           ║"
              echo "  ║  PureScript client for Weapon AI coding agent             ║"
              echo "  ╚═══════════════════════════════════════════════════════════╝"
              echo ""
              echo "  Commands:"
              echo "    spago build       Build the library"
              echo "    spago test        Run tests"
              echo "    spago run         Run the demo CLI"
              echo "    zeitschrift ...   Generate types from OpenAPI"
              echo ""
            '';
          };
        };
    };
}
