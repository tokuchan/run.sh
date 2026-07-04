# ADR 0017: Per-command host dispatch

## Status
Accepted.

## Context
Every command's `main.<ext>` runs inside the container by construction — that is the point of run.sh. But some commands cannot work that way: a command that itself drives another container runtime (e.g. shelling out to `podman`/`docker` to manage a sibling stack, or invoking `run.sh` for a different project) needs to run against the host's runtime socket, not one nested inside the container. There was no way to say "this particular command is the exception."

## Decision
Add a per-command setting, `dispatch`, read from a new command-directory file: `commands/<cmd>/conf` (or `conf.txt`). Two values are recognized: `host` and `container` (the default). Format matches `commands/run.conf`: `key = value`, `#` comments, blank lines ignored. Unknown keys and unknown values are both a hard error (exit 125), matching the strictness of the project-wide `run.conf` parser.

`dispatch` is loaded by `load_command_config` alongside `run` and `env` files, using the same root→leaf walk over the matched command path. Last-wins: a child directory's `conf` overrides an ancestor's, so a whole subtree can be set to `dispatch = host` once and a specific child can opt back into `dispatch = container` (or vice versa).

When a command resolves to `dispatch = host`:
- `detect_runtime`, `manage_image`, `mount_nix_store`, `build_cwd_mounts`, and `build_mirror_mounts` are all skipped — none of them are meaningful without a container.
- The env vars accumulated from `commands/env` files, plus the injected `RUN_PROJECT`/`RUN_COMMAND`/`RUN_ROOT` metadata, are `export`ed into the host process environment so the script sees the same environment either way.
- `main.<ext>` is `exec`'d directly, replacing the run.sh process, with the same remaining-args forwarding used for the container path.
- `--dry-run` prints the env exports and the resolved host command line instead of a container invocation.
- `--mirror`/`--mirror-ro` and `--timeout` are container-only; if the user passed them for a host-dispatched command, run.sh warns that they're ignored rather than silently dropping them.

## Alternatives considered

**A project-wide three-surface setting (CLI flag / env var / `run.conf` key).** Rejected: the need is per-command, not per-invocation or per-project. A global `--host` flag would force the caller to remember which commands need it every time, instead of the command declaring its own requirement once.

**A boolean sentinel file (`commands/<cmd>/host`, presence = host mode).** Considered for symmetry with `run`/`env`, but a bare presence check can't express "child overrides parent back to container" — it would need a second file or a magic content convention to un-set an inherited setting. A `key = value` conf file gives override-by-content for free and leaves room for future per-command settings without inventing a new file per setting.

**Fold `dispatch` into the existing `env` file namespace (e.g. `RUN_DISPATCH=host`).** Rejected: `env` files are contents to inject into the *container's* environment; overloading them to also control whether a container runs at all conflates two different concerns and would leak an internal-looking `RUN_DISPATCH` var into the actual env.

## Consequences
- `dispatch` is, like `name` in `commands/run.conf` (ADR-0016), an intentional exception to the three-surface rule (ADR-0005): it is a per-command declaration, not a runtime tunable with CLI/env/config surfaces.
- `commands/<cmd>/conf` is a new command-directory file alongside `run`, `env`, `help.md`, and `fs/`.
- Host-dispatched commands run with the caller's ambient host environment (beyond the explicitly exported vars) and host filesystem view as-is — there is no CWD mirroring to reason about because there is no container.
- A host-dispatched command's `main.<ext>` must be runnable directly on the host (right interpreter/toolchain on `PATH`) — that responsibility shifts from the Dockerfile/flake to the host environment for that specific command.
