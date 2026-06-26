# atlas-overlay

Nix flake overlay for [Atlas](https://atlasgo.io) - the official binary distribution from Ariga.

> **⚠️ Unfree License**: This package is marked `licenses.unfree` because Atlas is distributed under the [Atlas EULA](https://ariga.io/legal/atlas/eula), not an OSI-approved license. This repository's own flake uses `nixpkgs-unfree` so `nix develop` and `nix run` work without extra local config, but downstream consumers still need an unfree-enabled nixpkgs when importing the overlay into their own package set.

## Why this overlay?

The `atlas` package in nixpkgs builds the community edition from source using `buildGoModule`. The community build excludes Pro/Enterprise features that are gated behind the `ent` build tag:

- Functions and stored procedures
- Triggers
- Row-level security (RLS)
- Views
- `atlas login` command
- Other Pro features

This overlay fetches the official pre-built binary from Ariga which includes all features under the [Atlas EULA](https://ariga.io/legal/atlas/eula).

## Handling the Unfree License

Since Atlas uses `licenses.unfree`, downstream Nix configurations that import the overlay into their own package set must allow unfree packages. There are several approaches:

### Option A: Use `nixpkgs-unfree` with `follows` (Recommended)

The cleanest approach uses [numtide/nixpkgs-unfree](https://github.com/numtide/nixpkgs-unfree), which has `allowUnfree = true` built-in. The `follows` directive tells atlas-overlay to use this nixpkgs variant:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unfree.url = "github:numtide/nixpkgs-unfree/nixos-unstable";
    nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";  # Use our nixpkgs version
    atlas-overlay.url = "github:alleneubank/atlas-overlay";
    atlas-overlay.inputs.nixpkgs.follows = "nixpkgs-unfree";  # Inherit unfree config
  };

  outputs = { nixpkgs, nixpkgs-unfree, atlas-overlay, ... }: {
    devShells.x86_64-linux.default = nixpkgs-unfree.legacyPackages.x86_64-linux.mkShell {
      packages = [ atlas-overlay.packages.x86_64-linux.atlas ];
    };
  };
}
```

**What `follows` does**: Without it, each flake input fetches its own copy of dependencies. `follows` deduplicates by saying "use this other input instead of fetching your own." This ensures atlas-overlay builds against the same nixpkgs (with unfree enabled) that you're using elsewhere.

### Option B: Set `allowUnfree` in nixpkgs config

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    atlas-overlay.url = "github:alleneubank/atlas-overlay";
  };

  outputs = { nixpkgs, atlas-overlay, ... }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      overlays = [ atlas-overlay.overlays.default ];
    };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ pkgs.atlas ];
    };
  };
}
```

### Option C: Environment variable

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure github:alleneubank/atlas-overlay
```

## Usage

### As a flake input (with overlay)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    atlas-overlay.url = "github:alleneubank/atlas-overlay";
  };

  outputs = { nixpkgs, atlas-overlay, ... }: let
    # Must allow unfree for the overlay to work
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
      overlays = [ atlas-overlay.overlays.default ];
    };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ pkgs.atlas ];
    };
  };
}
```

### Using the package directly

```nix
{
  # With nixpkgs-unfree (no extra config needed)
  packages = [ atlas-overlay.packages.x86_64-linux.atlas ];
}
```

### Run directly

```bash
nix run github:alleneubank/atlas-overlay -- version
```

### Development shell

```bash
nix develop github:alleneubank/atlas-overlay
atlas version
```

## Supported platforms

- `x86_64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## License

The overlay code in this repository is MIT licensed.

The Atlas binary itself is distributed under the [Atlas EULA](https://ariga.io/legal/atlas/eula). By using this overlay, you agree to the Atlas EULA terms.

## Version

Current Atlas version: **v1.0.0**
