# ADR 0003: All boolean flags are reversible; verbosity and dry-run are first-class

## Status
Accepted

## Context
`run.sh` will accumulate boolean flags over time (env-host forwarding, CWD mirroring, TTY, etc.). Users composing `run.sh` invocations in scripts or aliases need a reliable way to override a default-on flag without rewriting the whole invocation.

## Decision
Every boolean flag has a `--no-<flag>` counterpart that negates it. **Last flag on the command line wins, unconditionally.** This applies even when flags appear to conflict semantically (e.g. `--force-rebuild --no-build` → no build; `--no-build --force-rebuild` → force rebuild). There are no special-case precedence rules between flags — the rule is purely positional. This matches the flag semantics of Click (Python) and is the general model to follow when in doubt about new flag behavior.

The config hierarchy (CLI > env var > `run.conf` > default) ensures that environment variables set defaults which CLI flags can override in either direction. Example: `RUN_NO_BUILD=1` in the environment is overridden by `--force-rebuild` on the CLI, just as `--force-rebuild` in a config alias is overridden by `--no-build` appended afterward.

Example: `--env-host` / `--no-env-host`, `--cwd` / `--no-cwd`.

Additionally, two cross-cutting control flags:

**Verbosity** follows SSH convention:
- `-v` / `--verbose`: increase verbosity (repeatable: `-vv`, `-vvv`)
- `-q` / `--quiet`: suppress all non-error output
- These are mutually exclusive; last one wins if both provided.

**Dry run**: `--dry-run` (env: `RUN_DRY_RUN=1`) prints the fully-resolved container invocation command — image, all mount flags, all env flags, the command string — without executing it. Useful for debugging and for piping the command into other tools.

## Consequences
- Flag composition in aliases and Makefiles is safe: `run.sh --no-cwd ...` reliably disables CWD mirroring regardless of defaults.
- Dry-run output is machine-readable enough to be piped or grepped.
- Every new flag added to `run.sh` must ship its `--no-` counterpart or the ADR is violated.
