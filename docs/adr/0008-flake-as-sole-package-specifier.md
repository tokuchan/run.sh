# flake.nix is the sole specifier of toolchain packages

The `Dockerfile` is fixed infrastructure — it installs Nix and configures flake support. Users must not add packages to it directly. All project tooling is declared in `flake.nix`, which the container reads at build time via `nix profile install`. This makes `flake.nix` the single authoritative source of what tools are available inside the container.

The alternative — editing the Dockerfile to add packages — is simpler for Docker-familiar users but defeats reproducibility and couples package management to image rebuilds. Ad-hoc `RUN apt-get install` lines bypass the Nix store entirely. Keeping the Dockerfile as sealed infrastructure (Nix + flake config only, no packages) and the flake as the user-facing surface preserves the Nix guarantee: packages are pinned, composable, and auditable via `flake.lock`. Packages are installed at runtime into a host-side nix store (see ADR-0011), not baked into the image.

The `--init-container` stub includes a comment directing users to `flake.nix` instead of editing the Dockerfile. The `--init-flake` stub is a working example with a clearly marked section for adding packages.
