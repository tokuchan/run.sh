# run.sh — Domain Glossary

## Terms

### Runner
The `run.sh` script renamed to match the project (e.g. `foo`). Its `basename` is the project identity. Invoked directly or via symlink — either works because `basename $0` yields the project name in both cases. The runner owns command dispatch, container lifecycle, and all run.sh flags. If `basename $0` does not match the expected project name (the `name` key in `commands/run.conf`, or `basename` of the run root if `name` is absent), a `[WARN]` is emitted suggesting the script be renamed. This suppresses false warnings for projects whose runner name intentionally matches their directory or `run.conf` name (including the `run.sh` project itself).

### Command
A directory in the command tree that represents one invocable operation. A command directory may contain: `main.<ext>` (the program to run), `run` or `run.txt` (mount configuration), `env` or `env.txt` (environment variables), `help.md` or `help.txt` (user-facing documentation), and `fs/` (host-side mount sources). The command is the atomic unit of configuration — replaces Stem.

### Command tree
The `commands/` directory at the run root. Contains the full set of available commands for a project, arranged as a directory hierarchy where each subdirectory is a command or sub-command.

### Command path
The resolved sequence of directory names that identifies a specific command (e.g. `release build` → `commands/release/build/`). Determined by greedy longest match against the command tree: run.sh walks the argument list token by token into `commands/`, stopping at the first token that starts with `-` or has no matching child directory.

### Command dispatch
The process by which run.sh resolves the command path from the argument list, loads configuration from each directory level along the path, then invokes `main.<ext>` with the remaining arguments. Configuration (mounts, env vars) is accumulated from the command tree root down to the matched command directory — each level inherits from its parent, with the deepest (most specific) directory winning on conflicts.

### CWD mirror
The host's current working directory, bind-mounted at the same absolute path inside the container, with `--workdir` set to match. Always active unless `--no-cwd` is passed. If the CWD path conflicts with a mount defined in a command's `run` file, the CWD mirror takes precedence and a warning is emitted to the log.

### Project root mirror
The root of the VCS repository containing the CWD, bind-mounted at the same absolute path inside the container. Always active alongside the CWD mirror (both are on by default, both disabled by `--no-cwd`). Conflict resolution is the same as for CWD mirror: project root mirror wins over command mounts, with a warning.

### Container runtime
Podman or Docker. Auto-detected at startup (try `podman`, fall back to `docker`). Overridable via `run.conf`, `RUN_RUNTIME` env var, or `--runtime` flag. The goal is output indistinguishable from locally-installed tools, so UID/GID mapping is applied: podman uses `--userns=keep-id`; docker uses `--user $(id -u):$(id -g)`.

### Project root detection
Resolved in order: `jj root` → `git rev-parse --show-toplevel` → walk up from CWD until `commands/run.conf` is found. The directory containing `commands/` is the **run root**. Overridable with `--project-root <path>` / `RUN_PROJECT_ROOT`. Error if no run root can be determined.

### Run root
The directory containing the `commands/` subtree. Identified by the presence of `commands/run.conf`. When inside a VCS repo, the run root is the VCS project root. Outside a VCS repo, the run root is discovered by walking up from CWD. `Dockerfile` and `flake.nix` also live here.

### Path mirror
An arbitrary host path, canonicalized via `readlink -f` (or POSIX equivalent) to its absolute form, then bind-mounted at that same absolute path inside the container. Specified with `--mirror <path>` (read-write) or `--mirror-ro <path>` (read-only). Repeatable. `~` in the path is expanded before canonicalization.

### Project config
`commands/run.conf` at the command tree root. Holds project-wide defaults for the runner's own settings (`image`, `runtime`, `store`, `timeout`, `name`, etc.). Its presence is what marks the run root. The `name` key sets the expected runner name — used to suppress the rename warning when the directory name and runner name intentionally differ. Format: `snake_case = value` per line, `#` comments, blank lines ignored. Parsed not sourced. Unknown keys are a hard error. All settings here are overridable by environment variable and by CLI option. Does not hold mount or env configuration — those live in `commands/run` and `commands/env`.

### Three-surface setting
Every configurable setting has exactly three surfaces: a CLI option (`--kebab-case` / `--no-kebab-case`), an environment variable (`RUN_SCREAMING_SNAKE`), and a `run.conf` key (`snake_case`). Precedence: CLI > env var > `run.conf` > built-in default.

### Config hierarchy
Command-line option > environment variable > `run.conf` > built-in default. Applies to every configurable setting.

### Command load order
The sequence in which command configuration is applied: command tree root (`commands/run`, `commands/env`) → each directory level along the command path in order → deepest matched command directory last. Mount specs accumulate across all levels; env var conflicts and mount destination conflicts are resolved last-wins (deepest directory wins).

### Command conf
`commands/<cmd>/conf` (or `conf.txt`) — a per-command settings file, `key = value` per line, `#` comments and blank lines ignored. Loaded by `load_command_config` alongside `run` and `env` files, same root→leaf walk, same last-wins override semantics. Currently recognizes one key: `dispatch`. Unknown keys and unknown values are a hard error (exit 125), matching `commands/run.conf`'s strictness. See ADR-0017.

### Dispatch target
The per-command setting (`dispatch` in `commands/<cmd>/conf`) that decides whether a command's `main.<ext>` runs inside the container (`dispatch = container`, the default) or directly on the host (`dispatch = host`). Inherited root→leaf like other command config — set once on a parent directory to cover a whole subtree, override on a child to opt back out. An intentional exception to the three-surface rule (ADR-0005), alongside `name` in `commands/run.conf` (ADR-0016) — it is a per-command declaration, not a project-wide runtime tunable. See ADR-0017.

### Host dispatch
What happens when a command's resolved dispatch target is `host`: `detect_runtime`, `manage_image`, `mount_nix_store`, `build_cwd_mounts`, and `build_mirror_mounts` are all skipped, and `main.<ext>` is `exec`'d directly on the host with the remaining args, replacing the run.sh process. The env vars accumulated from `commands/env` files, plus the injected `RUN_PROJECT`/`RUN_COMMAND`/`RUN_ROOT` metadata, are exported into the host process environment first, so the script sees the same environment it would inside the container. `--mirror`/`--mirror-ro` and `--timeout` are container-only; run.sh warns (rather than silently ignoring) if they're set for a host-dispatched command. `--dry-run` prints the env exports and resolved host command line instead of a container invocation. See ADR-0017.

### Option parsing
The runner greedily consumes its own recognized options from the front of the argument list. The first non-option, non-`--` token begins command dispatch. `--` forces an explicit switch to command dispatch: everything after `--` is treated as the command path and its arguments. This allows run.sh options and command path tokens to coexist unambiguously (e.g. `foo --verbose -- release build` sets verbosity then dispatches to `commands/release/build/`).

### Command forwarding
After command dispatch resolves `main.<ext>`, run.sh invokes it inside the container with the remaining arguments forwarded verbatim via `--entrypoint bash … -c '"$@"' -- main.<ext> "$@"`. Word boundaries established by the host shell are preserved exactly. The runner's own name and the command path tokens are consumed by dispatch and never forwarded.

### Runner metadata
Three environment variables injected by the runner into every container invocation, regardless of what `commands/env` files specify. Read-only — cannot be overridden by command configuration. `RUN_PROJECT`: the runner's `basename $0` (e.g. `foo`). `RUN_COMMAND`: the slash-separated resolved command path (e.g. `release/build`). `RUN_ROOT`: the absolute host path of the run root, available inside the container via the project root mirror. Scripts use these to construct paths to sibling files without hardcoding.

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

### Auto-build
Automatic construction of the container image when it is absent from the local runtime. On by default; suppressed with `--no-build` / `RUN_NO_BUILD=1`. When triggered, run.sh runs `<runtime> build -t <image> <run-root>` using `<run-root>/Dockerfile` as the build file (convention, not configurable). Handled in §07 image management, after config and env are applied but before stem resolution. With the nix-store-on-host architecture, the image is thin (no packages baked in), so auto-build is rarely triggered after the first run.

### Package install fingerprint
A potential future optimisation: hash `flake.nix` + `flake.lock` and store the result to detect when `nix develop` evaluation can be skipped. Not implemented in the current iteration — `nix develop --command` is self-managing and its per-invocation evaluation overhead is acceptable. May be revisited if startup latency becomes a concern.

### Command forwarding (devShell mode)
Instead of `--entrypoint bash -c '"$@"' -- <cmd>`, run.sh forwards the user command via `nix develop <run-root> --command bash -c '"$@"' -- <cmd>` inside the container. `nix develop` evaluates the flake's `devShells.default`, sets up PATH and environment, downloads any missing packages into the mounted nix store, then runs the command. The run root is available inside the container at its host absolute path (via the project root mirror).

### Image management
The §07 section of run.sh. Runs after `apply_env`, before stem resolution. Sequence: detect runtime → `--clean` (rmi + exit if requested) → image-absent check (auto-build if missing) → staleness check (auto-rebuild if stale). Dry-run mode includes §07 — it shows what image would be used and whether a build is needed — but still skips `invoke_container`.

### Auto-rebuild
Automatic reconstruction of the container image when it is present but stale. On by default; suppressed with `--no-rebuild` / `RUN_NO_REBUILD=1`. Staleness is determined by hashing `Dockerfile` and `flake.nix` at the run root and comparing against a fingerprint stored as a `run.fingerprint` label on the image (set at build time via `--label`). Stale if the hashes differ. `--no-rebuild` does not imply `--no-build` — a missing image is still built even when rebuild is suppressed.

### Force-rebuild
An explicit `--force-rebuild` / `RUN_FORCE_REBUILD=1` flag that triggers a full image rebuild unconditionally, bypassing the staleness check. The image label fingerprint is updated correctly after the build. Does not imply `--clean` — the old image layers are replaced in place by the runtime.

### Clean
`--clean` removes the container image from the local runtime (`<runtime> rmi <image>`) and exits immediately without running a command or rebuilding. Used to free disk space or force a fully fresh build on the next invocation.

### Init
Starter files written by the runner to bootstrap a new project. Four init flags exist: `--init-container` writes `Dockerfile`, `--init-flake` writes `flake.nix`, `--init-config` writes `run.conf`, `--init-commands` scaffolds a `commands/` directory with a root `help.md` and a sample `hello/main.sh`. `--init` is shorthand for all four. Init files are always written to CWD — run.sh does not attempt run root detection in init mode. Writing `run.conf` to CWD marks CWD as the run root for all future invocations from that directory. If the target file already exists, run.sh emits a warning and skips that file — it never clobbers existing content. If VCS root detection would have resolved a different directory than CWD, an informational log message notes the discrepancy. Init flags cause immediate exit after writing; they cannot be combined with a command invocation.

`.gitignore` is handled in two places. `--init-commands` writes `commands/.gitignore` containing `**/fs/` — a single entry that covers `fs/` directories at any depth within the command tree, including the local nix store, automatically for all future commands. `--init` (or `--init-container`) smart-appends `result` to the root `.gitignore` only. Neither file is ever clobbered; root `.gitignore` is created if absent or appended to if present; `commands/.gitignore` is written fresh only if absent.

### Toolchain specifier
`flake.nix` is the sole authoritative source of what packages are available inside the container. The `Dockerfile` is sealed infrastructure (installs Nix and enables flakes only — no packages) and must not be edited to add packages. Users add tools by editing `flake.nix` directly, or via `--add` / `--remove` / `--search` (see Package management). Packages are installed at runtime into a host-side nix store that is mounted into the container, not baked into the image at build time. This separation is enforced by convention and documented in ADR-0008.

### Nix store — local mode
The nix store lives inside the project's `commands/fs/nix/` directory, mounted at `/nix` inside the container. Each project has an isolated store. Used for hermetic projects. `commands/fs/nix/` must be gitignored. Selected by `store = local` in `commands/run.conf` (or `RUN_STORE=local` / `--store local`).

### Nix store mount
A special-purpose mount constructed in §07 alongside the image management phase, using the same mechanism as CWD mirror and project root mirror (appended directly to `RUN_MOUNT_PAIRS`). The host path is resolved from the `store` config key — shared mode uses `$XDG_CACHE_HOME/run/nix/`; local mode uses `<run-root>/commands/fs/nix/`. The directory is created if absent. Always mounted at `/nix` inside the container.

### Nix store — shared mode
The nix store lives in an XDG-compliant cache directory on the host (e.g. `$XDG_CACHE_HOME/run/nix/`, defaulting to `~/.cache/run/nix/`) and is shared across all projects. Safe to share because the Nix store is content-addressed — different package versions have different hashes and coexist without conflict. This is the preferred default for most projects. Eliminates gigabytes of per-project duplicates. Documented in ADR-0012.

### Package management
The set of three management flags — `--add <pkg>`, `--remove <pkg>`, `--search <term>` — that let users modify `flake.nix` without hand-editing. All three are management operations: they exit without running a container command, just as `--init` and `--clean` do. When combined in one invocation, they execute in order: `--search` first (prints results), then `--add` operations, then `--remove` operations. `manage_image` (auto-build) runs before any package operation since a container is needed to run nix commands. Inspired by `uv add` / `uv remove`.

### Nix attribute path
The exact identifier for a package in the nixpkgs attribute set, used as the argument to `--add` and `--remove`. Examples: `nodejs`, `python311`, `rustc`, `ripgrep`. Must match an attribute that exists in nixpkgs exactly — `--add` validates existence via `nix eval nixpkgs#<name>` inside the container before editing `flake.nix`. Wrong names are rejected immediately with exit 125.

### Package sentinel
The comment `# run:packages` placed inside the `packages = with pkgs; [ ... ]` list in `flake.nix`. Acts as an insertion point for `--add` (inserts a new line above it via sed) and an anchor for `--remove` (deletes the target package line). Written by `--init-flake` with a note that it must not be removed. If the sentinel is absent when `--add` or `--remove` is called, run.sh exits 125 with a clear error directing the user to add packages manually. Documented in ADR-0013.

### Package search
`--search <term>` runs `nix search nixpkgs <term>` inside the container and prints the results to stdout. Used for discovery when the exact nix attribute path is unknown. Exits 0 after printing. Output is the raw nix search output — package names, versions, descriptions. Combine with `--add` in a separate invocation once the exact attribute path is identified.

### Package pre-warm
Running any command (e.g. `foo --help`) after `--add` to trigger `nix develop` and download newly-added packages into the nix store before the first real command invocation. Not automatic — `--add` prints an info-level suggestion to do this. The next real command invocation would trigger the download anyway; pre-warming just moves the latency to a moment the user expects it.

### Command help
Per-command documentation stored as `help.md` or `help.txt` in the command directory. The first paragraph is the short description — used in auto-generated listings. `--help` after any command path prefix displays the help file for the deepest matched command directory (run.sh intercepts `--help` and never forwards it to `main.<ext>`). `--help` with no command path shows top-level runner help followed by the shallow command listing.

### Command listing
The auto-generated output shown when the runner is invoked with a command path that has no `main.<ext>` (including the top-level no-subcommand case). If a `help.md` or `help.txt` exists in the matched directory, its first paragraph is displayed before the listing. Displays only the immediate children of that directory (non-recursive), with the first sentence of each child's `help.md`/`help.txt` as a trailing description. `--help` produces a full recursive listing from the matched directory. `--list-commands` produces a machine-readable list of all commands in the entire tree: one per line, slash-separated path, tab-separated from its usage line (first sentence of `help.md`/`help.txt`); description omitted if no help file exists.

### Help pager
When `--help` is invoked and stdout is a terminal, run.sh pipes the full manual through a pager. Detection chain: `$PAGER` → `less` → `more` → `cat`. When `less` is selected directly (i.e. `$PAGER` is not set), it is invoked as `less -FRX` so that: content fitting on one screen exits immediately (`-F`), SGR codes render correctly (`-R`), and the screen is not cleared on exit (`-X`). When `$PAGER` is set, it is invoked verbatim.

### SGR primitives
Shell variables set at the start of `help()` to ANSI/SGR escape sequences, or to empty strings when SGR is suppressed. Names reflect visual role: `BOLD`, `DIM`, `RESET`, and color names (`RED`, `GREEN`, `CYAN`, `YELLOW`, `MAGENTA`). Set to empty when `$NO_COLOR` is set or stdout is not a terminal.

### Help semantic variables
Shell variables that express structural roles in the help text, defined in terms of SGR primitives. `SECTION` styles top-level section headers; `SUBSECTION` styles subsection labels within OPTIONS. Because they reference primitives, zeroing out the primitives (for `NO_COLOR` or non-TTY output) automatically strips all formatting without touching the help text itself.

### Run-time limit
A maximum wall-clock duration for the container command, set via `--timeout <seconds>` / `RUN_TIMEOUT` / `timeout` in `run.conf`. When exceeded, run.sh stops the container with `docker stop` and exits 124. `0` means no limit (the default). Applies to the container run only — not to auto-build or auto-rebuild. Implies `--no-tty` because the implementation runs the container detached. Documented in ADR-0015.

### Timeout sentinel
A temporary file written by the background timer subshell when it fires (`docker stop` is called). Its presence after `docker wait` returns distinguishes a timeout exit from a normal or user-interrupted exit. Cleaned up immediately after inspection.
