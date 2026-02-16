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
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      purescript-overlay,
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

          # PureScript toolchain
          pursTools = with pkgsWithPS; [
            purs
            spago-unstable
            purs-tidy
            purs-backend-es
          ];

          # Path to openapi spec (relative to repo root)
          openapiSpec = ../../packages/openapi/openapi.json;

          # Fixed-output derivation to fetch spago dependencies
          # This runs with network access and produces a hash-verified output
          spagoDeps = pkgsWithPS.stdenv.mkDerivation {
            pname = "weapon-ps-spago-deps";
            version = "0.1.0";

            # No source - we just fetch deps
            dontUnpack = true;

            nativeBuildInputs = pursTools ++ [
              pkgsWithPS.git
              pkgsWithPS.cacert
            ];

            buildPhase = ''
              export HOME=$TMPDIR
              export SSL_CERT_FILE=${pkgsWithPS.cacert}/etc/ssl/certs/ca-bundle.crt

              # Copy spago.yaml to temp dir
              cp ${./spago.yaml} spago.yaml

              # Create minimal src to satisfy spago
              mkdir -p src
              echo "module Main where" > src/Main.purs
              echo "main = pure unit" >> src/Main.purs

              # Fetch dependencies
              spago install
            '';

            installPhase = ''
              mkdir -p $out
              cp -r .spago $out/ || true
              cp -r $HOME/.cache/spago-nodejs $out/cache || true
            '';

            # Fixed-output derivation - allows network access
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };

          # Build the CLI using pre-fetched deps
          weapon-cli = pkgsWithPS.stdenv.mkDerivation {
            pname = "weapon-ps";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = pursTools ++ [
              pkgsWithPS.esbuild
              pkgsWithPS.nodejs
              pkgsWithPS.git
            ];

            buildPhase = ''
              export HOME=$TMPDIR

              # Link pre-fetched deps
              if [ -d ${spagoDeps}/.spago ]; then
                cp -r ${spagoDeps}/.spago .spago
                chmod -R u+w .spago
              fi
              if [ -d ${spagoDeps}/cache ]; then
                mkdir -p $HOME/.cache
                cp -r ${spagoDeps}/cache $HOME/.cache/spago-nodejs
                chmod -R u+w $HOME/.cache/spago-nodejs
              fi

              # Build PureScript
              spago build

              # Bundle to a single JS file
              mkdir -p dist
              spago bundle --platform node --bundle-type app --outfile dist/weapon-ps.js
            '';

            installPhase = ''
              mkdir -p $out/bin $out/lib

              # Copy the bundle
              cp dist/weapon-ps.js $out/lib/

              # Create wrapper script
              cat > $out/bin/weapon-ps << EOF
              #!/usr/bin/env bash
              exec ${pkgsWithPS.nodejs}/bin/node "\$(dirname "\$0")/../lib/weapon-ps.js" "\$@"
              EOF
              chmod +x $out/bin/weapon-ps
            '';
          };

          # Simple script-based runner that works without complex nix build
          # Copies source to a writable temp dir and builds there
          weapon-ps-script = pkgsWithPS.writeShellScriptBin "weapon-ps" ''
            set -euo pipefail
            export PATH="${
              pkgsWithPS.lib.makeBinPath (
                pursTools
                ++ [
                  pkgsWithPS.nodejs
                  pkgsWithPS.git
                  pkgsWithPS.cacert
                ]
              )
            }:$PATH"
            export SSL_CERT_FILE="${pkgsWithPS.cacert}/etc/ssl/certs/ca-bundle.crt"

            # Use a persistent build directory in user's cache
            CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/weapon-purescript"
            BUILD_DIR="$CACHE_DIR/build"

            # Check if source has changed (compare spago.yaml and src/)
            SRC_DIR="${./.}"
            HASH=$(${pkgsWithPS.coreutils}/bin/sha256sum "$SRC_DIR/spago.yaml" "$SRC_DIR/package.json" $(find "$SRC_DIR/src" -name '*.purs' -o -name '*.js' 2>/dev/null) 2>/dev/null | ${pkgsWithPS.coreutils}/bin/sha256sum | cut -d' ' -f1)
            HASH_FILE="$CACHE_DIR/.src-hash"

            NEEDS_REBUILD=false
            if [ ! -f "$HASH_FILE" ] || [ "$(cat "$HASH_FILE" 2>/dev/null)" != "$HASH" ]; then
              NEEDS_REBUILD=true
            fi

            if [ "$NEEDS_REBUILD" = true ]; then
              echo "Setting up PureScript SDK build..."
              mkdir -p "$CACHE_DIR"
              # Remove old build dir completely (force remove even read-only files)
              chmod -R u+w "$BUILD_DIR" 2>/dev/null || true
              rm -rf "$BUILD_DIR"
              mkdir -p "$BUILD_DIR"

              # Copy source files and make them writable
              cp -r "$SRC_DIR/src" "$BUILD_DIR/"
              cp "$SRC_DIR/spago.yaml" "$BUILD_DIR/"
              cp "$SRC_DIR/package.json" "$BUILD_DIR/"
              [ -d "$SRC_DIR/test" ] && cp -r "$SRC_DIR/test" "$BUILD_DIR/" || true
              chmod -R u+w "$BUILD_DIR"

              cd "$BUILD_DIR"

              echo "Installing npm dependencies..."
              npm install --silent

              echo "Installing PureScript dependencies..."
              spago install

              echo "Building..."
              spago build

              # Save the hash
              echo "$HASH" > "$HASH_FILE"
            else
              cd "$BUILD_DIR"
            fi

            # Set up NODE_PATH for xhr2
            export NODE_PATH="$BUILD_DIR/node_modules:$NODE_PATH"

            # Run
            exec spago run -- "$@"
          '';
        in
        {
          packages = {
            default = weapon-ps-script;
            script = weapon-ps-script;

            # Full nix build (requires updating spagoDeps hash)
            # cli = weapon-cli;

            # Just the library (for use as dependency)
            lib = pkgsWithPS.stdenv.mkDerivation {
              pname = "weapon-purescript-lib";
              version = "0.1.0";
              src = ./.;

              nativeBuildInputs = pursTools ++ [ pkgsWithPS.git ];

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

            # Note: For codegen from OpenAPI, use zeitschrift manually:
            #   nix run github:weyl-ai/zeitschrift -- codegen --lang purescript ...
          };

          apps = {
            default = {
              type = "app";
              program = "${weapon-ps-script}/bin/weapon-ps";
            };
          };

          devShells.default = pkgsWithPS.mkShell {
            buildInputs = pursTools ++ [
              pkgsWithPS.nodejs
              pkgsWithPS.esbuild
              pkgsWithPS.git
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
              echo "    # For codegen: nix run github:weyl-ai/zeitschrift -- ..."
              echo ""
              echo "  Nix:"
              echo "    nix run           Run the CLI (builds on first run)"
              echo "    nix develop       Enter dev shell"
              echo ""
            '';
          };
        };
    };
}
