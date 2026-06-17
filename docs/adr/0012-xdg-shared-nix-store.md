# Shared nix store follows XDG Base Directory conventions

The shared nix store lives at `$XDG_CACHE_HOME/run/nix/` (defaulting to `~/.cache/run/nix/` when `$XDG_CACHE_HOME` is unset). It is bind-mounted at `/nix` inside the container and shared across all projects that use shared-mode store.

XDG Base Directory conventions (XDG_CACHE_HOME, XDG_CONFIG_HOME, XDG_DATA_HOME) are the standard for user-level tool data on Linux. Placing run's cache under `$XDG_CACHE_HOME/run/` is consistent with tools like cargo, pip, and go. The cache home is appropriate (not config or data) because the nix store can be fully regenerated from `flake.lock` — it is a derived artifact, not primary data.

Sharing the store across projects is safe because the Nix store is content-addressed: every path in `/nix/store` encodes a cryptographic hash of its contents and dependencies. Two projects requiring different versions of the same library produce distinct store paths that coexist without conflict. Nix's garbage collector manages store cleanup.

The alternative — per-project stores — is available as local mode (see ADR-0011) for projects requiring hermetic isolation. The shared store is the default.
