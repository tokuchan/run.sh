# ADR 0018: Per-command `run` file renamed to `mount`

## Status
Accepted.

## Context
The per-command `run`/`run.txt` file holds exactly one thing — a list of bind-mount destinations (`/container/path[:ro]` per line). The name `run` didn't say that, and read as an easy mismatch against the project-wide `commands/run.conf` (a different file, a different concern — image/runtime/store/timeout). ADR-0017 then added a second per-command file, `conf`, for `key = value` settings (currently just `dispatch`). With two per-command config files now in play, the boundary between "a list of mount specs" and "a set of key=value settings" needed a name that carried the distinction on its face.

## Decision
Rename `run`/`run.txt` to `mount`/`mount.txt`. No coexistence: the old name is no longer read for mount configuration at all.

Two strictness changes ride along with the rename, both in service of the same "mount holds only mounts" boundary:

- If a directory along the matched command path still has a `run` or `run.txt` file, `load_command_config` exits 125 immediately, naming the file and telling the user to rename it to `mount`. Without this, a project that didn't migrate would have its mounts silently stop applying — worse than a loud failure, since nothing about "invocation succeeded, container started" signals that a mount is missing.
- A line in `mount` that isn't a mount spec, comment, or blank used to log a warning and get dropped. It's now a hard error (exit 125) pointing the user at `conf` for non-mount settings. This isn't a data migration — the parser never accepted key=value lines here, so there's nothing to actually move — but it closes off `mount` from ever quietly growing settings the way `run` could have.

Both checks are lazy: only directories `load_command_config` already walks for the currently-matched command path are checked, matching how `env`/`conf`/`mount` are all resolved per-invocation rather than by scanning the whole `commands/` tree up front.

## Consequences
- Any project with an existing `commands/<cmd>/run` or `run.txt` must rename it to `mount`/`mount.txt` before its next invocation of that command path, or run.sh exits 125.
- `commands/run.conf` (the project-wide file) is unaffected — this rename is scoped entirely to the per-command mount file.
