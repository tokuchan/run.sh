# run.sh — Domain Glossary

## Terms

### Stem
The name used to match a mount-set and env-set to a subcommand. Resolved via symlink dispatch first: if `basename $0` is not `run.sh`, the stem is `basename $0`. Otherwise the stem is the first positional argument after `run.sh`'s own options. Used to locate `<stem>.run`, `fs/<stem>/`, and `<stem>.env`.

### Mount-set
A pairing of a filesystem directory (`fs/<stem>/`) and a mount-config file (`<stem>.run`) that together define the bind mounts for one invocation context. The `default` mount-set is always auto-loaded first. Additional mount-sets are composed via `@include <name>` directives inside `.run` files.

### Env-set
A `.env` file (`<stem>.env`) whose contents are injected as environment variables into the container for one invocation context. Always paired with its mount-set — a stem is the atomic unit of configuration. `@include <name>` in a `.run` file loads both `<name>.run` and `<name>.env` together.

### CWD mirror
The host's current working directory, bind-mounted at the same absolute path inside the container, with `--workdir` set to match. Always active unless `--no-cwd` is passed. If the CWD path conflicts with a mount defined in a `.run` file, the CWD mirror takes precedence and a warning is emitted to the log.

### Project root mirror
The root of the VCS repository containing the CWD, bind-mounted at the same absolute path inside the container. Always active alongside the CWD mirror (both are on by default, both disabled by `--no-cwd`). Conflict resolution is the same as for CWD mirror: project root mirror wins over `.run` mounts, with a warning.

### Container runtime
Podman or Docker. Auto-detected at startup (try `podman`, fall back to `docker`). Overridable via `run.conf`, `RUN_RUNTIME` env var, or `--runtime` flag. The goal is output indistinguishable from locally-installed tools, so UID/GID mapping is applied: podman uses `--userns=keep-id`; docker uses `--user $(id -u):$(id -g)`.

### Project root detection
Resolved in order: `jj root` → `git rev-parse --show-toplevel` → walk up from CWD until `run.conf` is found. The directory containing `run.conf` is the **run root** — all stem files (`*.run`, `*.env`, `fs/`) are resolved relative to it. Overridable with `--project-root <path>` / `RUN_PROJECT_ROOT`. Error if no run root can be determined.

### Run root
The directory containing `run.conf`. This is where stem files and `fs/` directories live. When inside a VCS repo, the run root is the VCS project root. Outside a VCS repo, the run root is discovered by walking up from CWD.

### Path mirror
An arbitrary host path, canonicalized via `readlink -f` (or POSIX equivalent) to its absolute form, then bind-mounted at that same absolute path inside the container. Specified with `--mirror <path>` (read-write) or `--mirror-ro <path>` (read-only). Repeatable. `~` in the path is expanded before canonicalization.

### Default stem
The reserved stem `default`. Its mount-set (`default.run` / `fs/default/`) and env-set (`default.env`) are always loaded first, before the resolved stem and any `@include` directives. Provides project-wide defaults.

### Project config
`run.conf` at the project root. Holds project-wide defaults for any configurable setting. Format: `snake_case = value` per line, `#` comments, blank lines ignored. Parsed not sourced. Unknown keys are a hard error. All settings here are overridable by environment variable and by CLI option.

### Three-surface setting
Every configurable setting has exactly three surfaces: a CLI option (`--kebab-case` / `--no-kebab-case`), an environment variable (`RUN_SCREAMING_SNAKE`), and a `run.conf` key (`snake_case`). Precedence: CLI > env var > `run.conf` > built-in default.

### Config hierarchy
Command-line option > environment variable > `run.conf` > built-in default. Applies to every configurable setting.

### Optional stem file
Both `<stem>.run` and `<stem>.env` are optional. Absence is silently ignored. A stem with neither file is valid — it inherits from `default` and any `@include` chain. The only hard error for stem file absence is an `@include` directive referencing a name with no files at all (treated as a typo).

### Explicit stem
An additional stem loaded via `--stem <name>` / `-s <name>` (repeatable). Loaded after `default` and the auto-resolved stem, in left-to-right order. Later stems win on env var conflicts. Can also be listed in `run.conf` as a baseline set. `@include` directives within `.run` files are resolved before explicit stems, so `-s` stems always take final precedence.

### Load order
The sequence in which stems are applied: `default` → auto-resolved stem (with its `@include` tree) → `run.conf`-listed stems → `--stem` CLI stems (left-to-right). Mount sets accumulate; env var conflicts are resolved last-wins.

### Option parsing
`run.sh` greedily consumes its own recognized options from the front of the argument list, stopping at the first unrecognized token (which becomes the start of the user command). `--` forces an explicit split: everything after `--` is the user command regardless of content. This allows passing flags that collide with `run.sh`'s own options (e.g. `run -- -v g++` sends `-v` to `g++`, not to `run.sh`).

### Command forwarding
The user command is forwarded to the container via `--entrypoint bash … -c '"$@"' -- "$@"`. This passes each argument as a discrete word — no quoting reconstruction needed. Word boundaries established by the host shell are preserved exactly inside the container. Everything after `run.sh`'s own `--` separator is treated as the user command.

### TTY auto-detection
`run.sh` passes `-t` to the container runtime only when its own stdin is a terminal (`[ -t 0 ]`). Stdin (`-i`) is always connected. Overridable with `--tty` / `--no-tty`.

### Reversible flag
Every boolean flag ships with a `--no-<flag>` counterpart. Last flag on the command line wins. This is an invariant of the CLI — no flag is ever add-only.

### Log format
All `run.sh`-generated output goes to stderr in the format: `TIMESTAMP [SEVERITY] run: MESSAGE [JSON]`. Timestamp is ISO 8601 UTC. Severity is fixed-width 5-char bracket (`[DEBUG]`, `[INFO ]`, `[WARN ]`, `[ERROR]`). Optional trailing JSON object carries machine-readable diagnostic values. Stdout carries only the container's own stdout.

### Verbosity
SSH-style: `-v`/`--verbose` (repeatable for more detail) and `-q`/`--quiet` (suppress non-error output). Last one wins if both are provided.

### Dry run
`--dry-run` / `RUN_DRY_RUN=1`. Prints the fully-resolved container invocation — image, mounts, env flags, command — without executing it.
