# Nix store lives on the host and is mounted into the container

The container image is thin infrastructure: it installs Nix and enables flake support, but installs no packages. The Nix store (`/nix`) is bind-mounted from the host into the container at the same path. Packages declared in `flake.nix` are installed at runtime into this mounted store. The store persists across container invocations on the host filesystem.

This divorces two previously coupled concerns: container image lifecycle (Dockerfile changes) and package management (flake.nix / flake.lock changes). Image rebuilds become near-zero-frequency events — only needed when the base `nixos/nix` image or Nix configuration changes. Package updates require no image rebuild at all; the mounted store is updated in place.

The alternative — baking packages into the image via `nix profile install` at build time — was rejected because it couples `flake.lock` updates to image rebuilds, makes the image large, and prevents store sharing across projects.

Two store locations are supported:
- **Local mode**: `fs/default/nix/` at the run root (hermetic, per-project, must be gitignored)
- **Shared mode**: XDG cache directory (see ADR-0012) shared across projects (preferred default)

The `flake.nix` stub hardcodes `x86_64-linux` as the system for simplicity. ARM hosts (`aarch64-linux`, `aarch64-darwin`) are a near-term requirement; the stub includes a comment marking the string for easy substitution. Multi-system support via `flake-utils` is deferred to a future iteration.
