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

          # Build the CLI as a standalone Node.js bundle
          weapon-cli = pkgsWithPS.stdenv.mkDerivation {
            pname = "weapon-ps";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = pursTools ++ [
              pkgsWithPS.esbuild
              pkgsWithPS.nodejs
            ];

            buildPhase = ''
              export HOME=$TMPDIR

              # Install spago dependencies
              spago install

              # Build PureScript
              spago build

              # Bundle to a single JS file
              spago bundle --platform node --bundle-type app --outfile dist/weapon-ps.js
            '';

            installPhase = ''
              mkdir -p $out/bin $out/lib

              # Copy the bundle
              cp dist/weapon-ps.js $out/lib/

              # Create wrapper script
              cat > $out/bin/weapon-ps << 'EOF'
              #!/usr/bin/env bash
              exec ${pkgsWithPS.nodejs}/bin/node "$(dirname "$0")/../lib/weapon-ps.js" "$@"
              EOF
              chmod +x $out/bin/weapon-ps
            '';
          };
        in
        {
          packages = {
            default = weapon-cli;
            cli = weapon-cli;

            # Just the library (for use as dependency)
            lib = pkgsWithPS.stdenv.mkDerivation {
              pname = "weapon-purescript-lib";
              version = "0.1.0";
              src = ./.;

              nativeBuildInputs = pursTools;

              buildPhase = ''
                export HOME=$TMPDIR
                spago install
                spago build
              '';

              installPhase = ''
                mkdir -p $out
                cp -r output $out/
                cp -r src $out/
                cp spago.yaml $out/
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
              program = "${weapon-cli}/bin/weapon-ps";
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
              echo "  Nix:"
              echo "    nix run           Run the bundled CLI"
              echo "    nix build         Build the CLI package"
              echo ""
            '';
          };
        };
    };
}
