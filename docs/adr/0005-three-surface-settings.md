# ADR 0005: Every setting has three surfaces — CLI, env var, config key

## Status
Accepted

## Context
`run.sh` accumulates settings over time (image, runtime, stems, UID mapping, TTY, CWD mirroring, verbosity, etc.). Users need to set defaults at different scopes: project-wide (config file), shell session (env vars), and per-invocation (CLI flags).

## Decision
Every configurable setting is exposed on all three surfaces:

| Surface | Example | Scope |
|---|---|---|
| CLI option | `--runtime podman` / `--no-cwd` | Per-invocation, highest precedence |
| Environment variable | `RUN_RUNTIME=podman` | Shell session or script wrapper |
| `run.conf` key | `runtime = podman` | Project-wide default |

Precedence: CLI > env var > `run.conf` > built-in default.

Naming convention:
- CLI: `--kebab-case` / `--no-kebab-case`
- Env var: `RUN_SCREAMING_SNAKE` (always prefixed `RUN_`)
- Config key: `snake_case`

Unknown keys in `run.conf` are a hard error (to catch typos). Missing env vars are silently ignored (they simply don't override).

## Consequences
- The help text and man page can document each setting in a single table row covering all three surfaces.
- Adding a new setting requires implementing all three surfaces — no partial settings.
- `run.conf` doubles as a machine-readable project configuration, suitable for tooling that inspects it.
