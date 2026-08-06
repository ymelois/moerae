{
  description = "Moerae, an AI memory system";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        lib.genAttrs supportedSystems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [
                fenix.overlays.default
              ];
            }
          )
        );

      mkRustToolchain = pkgs: pkgs.fenix.stable.toolchain;

      manifestPath = ./Cargo.toml;
      lockfilePath = ./Cargo.lock;

      manifest = builtins.fromTOML (builtins.readFile manifestPath);

      inherit (manifest) package;
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          rustToolchain = mkRustToolchain pkgs;

          rustPlatform = pkgs.makeRustPlatform {
            cargo = rustToolchain;
            rustc = rustToolchain;
          };

        in
        {
          default = rustPlatform.buildRustPackage {
            pname = package.name;
            version = package.version;
            src = ./.;
            cargoLock.lockFile = lockfilePath;

            nativeBuildInputs = [
              pkgs.pkg-config
              pkgs.cmake
              rustPlatform.bindgenHook
              pkgs.autoPatchelfHook
            ];

            buildInputs = [
              pkgs.stdenv.cc.cc.lib
            ];

            preCheck = ''
              export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}:$LD_LIBRARY_PATH
            '';

            meta = {
              description = package.description;
              homepage = package.repository;
              license = lib.licenses.mit;
              mainProgram = "moerae";
            };
          };
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          rustToolchain = mkRustToolchain pkgs;
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              rustToolchain
            ];

            buildInputs = [
              pkgs.llvmPackages.libclang.lib
              pkgs.clang
              pkgs.cmake
              pkgs.stdenv.cc.cc.lib
            ];

            LIBCLANG_PATH = lib.makeLibraryPath [ pkgs.llvmPackages.libclang.lib ];
            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
          };
        }
      );

      overlays.default = final: prev: {
        moerae = self.packages.${prev.stdenv.hostPlatform.system}.default;
      };
    };
}
