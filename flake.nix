{
  description = "Atlas database migration tool - official binary";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree/nixos-unstable";
    nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unfree,
    flake-utils,
    ...
  }: let
    sources = builtins.fromJSON (builtins.readFile ./sources.json);
    version = sources.version;
    systems = builtins.attrNames sources.platforms;

    # Only the files the platform contract is derived from, so the check does not
    # rebuild on unrelated edits.
    contractSrc = builtins.path {
      name = "atlas-platform-contract-src";
      path = ./.;
      filter = path: _type:
        builtins.elem (baseNameOf path) [
          "README.md"
          "check-platforms"
          "sources.json"
          "update"
        ];
    };

    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = nixpkgs-unfree.legacyPackages.${system};
      source = sources.platforms.${system};

      atlas = pkgs.stdenv.mkDerivation {
        pname = "atlas";
        inherit version;

        src = pkgs.fetchurl {
          url = source.url;
          sha256 = source.sha256;
        };

        # Skip phases not needed for pre-built binary
        dontUnpack = true;
        dontBuild = true;
        dontConfigure = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          cp $src $out/bin/atlas
          chmod +x $out/bin/atlas
          runHook postInstall
        '';

        meta = with pkgs.lib; {
          description = "Atlas - declarative database schema migration tool";
          homepage = "https://atlasgo.io";
          license = licenses.unfree; # Atlas EULA
          platforms = builtins.attrNames sources.platforms;
          mainProgram = "atlas";
        };
      };
    in {
      packages = {
        inherit atlas;
        default = atlas;
      };

      apps = {
        atlas = flake-utils.lib.mkApp {
          drv = atlas;
          name = "atlas";
        };
        default = flake-utils.lib.mkApp {
          drv = atlas;
          name = "atlas";
        };
      };

      devShells.default = pkgs.mkShell {
        packages = [atlas];
      };

      checks.platform-contract = pkgs.runCommand "atlas-platform-contract" {
        nativeBuildInputs = [pkgs.bash pkgs.coreutils pkgs.jq];
        # nix is unavailable in the sandbox, so hand the checker the evaluated
        # flake facts instead of letting it shell out for them.
        flakeSystems = builtins.toJSON systems;
        metaPlatforms = builtins.toJSON atlas.meta.platforms;
        passAsFile = ["flakeSystems" "metaPlatforms"];
      } ''
        REPO_ROOT=${contractSrc} bash ${contractSrc}/check-platforms \
          --flake-systems "$flakeSystemsPath" \
          --meta-platforms "$metaPlatformsPath"
        touch $out
      '';
    });
  in
    outputs
    // {
      overlays.default = final: prev: {
        atlas = outputs.packages.${prev.stdenv.hostPlatform.system}.atlas;
      };
    };
}
