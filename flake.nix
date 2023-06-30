{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # Rust
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.dream2nix.flakeModuleBeta
      ];
      perSystem = { config, self', pkgs, lib, system, ... }: {
        # Rust project definition
        # cf. https://github.com/nix-community/dream2nix
        dream2nix.inputs."cargo-leptos" =
          {
            source = lib.sourceFilesBySuffices ./. [
              ".rs"
              "Cargo.toml"
              "Cargo.lock"
            ];
            projects."cargo-leptos" = { name, ... }: {
              inherit name;
              subsystem = "rust";
              translator = "cargo-lock";
            };
            packageOverrides =
              let
                common = {
                  add-deps = with pkgs; with pkgs.darwin.apple_sdk.frameworks; {
                    nativeBuildInputs = old: old ++ lib.optionals stdenv.isDarwin [
                      libiconv
                      CoreServices
                      Security
                    ];
                  };
                };
              in
              {
                # Project and dependency overrides:
                cargo-leptos = common // {
                  disableTest = {
                    cargoTestFlags = "--no-run";
                  };
                };
                cargo-leptos-deps = common;
              };
          };

        # Flake outputs
        packages = config.dream2nix.outputs.cargo-leptos.packages;
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.dream2nix.outputs.cargo-leptos.devShells.default
          ];
          shellHook = ''
            # For rust-analyzer 'hover' tooltips to work.
            export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}
          '';
          nativeBuildInputs = with pkgs; [
            cargo-watch
            rust-analyzer
          ];
        };
      };
    };
}
