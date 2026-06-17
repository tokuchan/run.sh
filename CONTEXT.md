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
A starter file written by `run.sh` to bootstrap a new project. Three init flags exist: `--init-container` writes `Dockerfile`, `--init-flake` writes `flake.nix`, `--init-config` writes `run.conf`. `--init` is shorthand for all three. Init files are always written to CWD — run.sh does not attempt run root detection in init mode. Writing `run.conf` to CWD marks CWD as the run root for all future invocations from that directory. If the target file already exists, `run.sh` emits a warning and skips that file — it never clobbers existing content. If VCS root detection would have resolved a different directory than CWD, an informational log message notes the discrepancy. Init flags cause immediate exit after writing; they cannot be combined with a command invocation.

`.gitignore` is handled specially: `--init` (or `--init-container`) performs a smart append — adding `fs/default/nix/` and `result` only if those entries are not already present. `.gitignore` is never skipped or clobbered wholesale; it is created if absent or appended to if present.

### Toolchain specifier
`flake.nix` is the sole authoritative source of what packages are available inside the container. The `Dockerfile` is sealed infrastructure (installs Nix and enables flakes only — no packages) and must not be edited to add packages. Users add tools by editing `flake.nix` directly, or via `--add` / `--remove` / `--search` (see Package management). Packages are installed at runtime into a host-side nix store that is mounted into the container, not baked into the image at build time. This separation is enforced by convention and documented in ADR-0008.

### Nix store — local mode
The nix store lives inside the project's `fs/default/nix/` directory, mounted at `/nix` inside the container. Each project has an isolated store. Used for hermetic projects. `fs/default/nix/` must be gitignored. Selected by `store = local` in `run.conf` (or `RUN_STORE=local` / `--store local`).

### Nix store mount
A special-purpose mount constructed in §07 alongside the image management phase, using the same mechanism as CWD mirror and project root mirror (appended directly to `RUN_MOUNT_PAIRS`). The host path is resolved from the `store` config key — shared mode uses `$XDG_CACHE_HOME/run/nix/`; local mode uses `<run-root>/fs/default/nix/`. The directory is created if absent. Always mounted at `/nix` inside the container.

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
Running `run true` after `--add` to trigger `nix develop` and download newly-added packages into the nix store before the first real command invocation. Not automatic — `--add` prints an info-level suggestion to do this. The next real command invocation would trigger the download anyway; pre-warming just moves the latency to a moment the user expects it.

### Help pager
When `--help` is invoked and stdout is a terminal, run.sh pipes the full manual through a pager. Detection chain: `$PAGER` → `less` → `more` → `cat`. When `less` is selected directly (i.e. `$PAGER` is not set), it is invoked as `less -FRX` so that: content fitting on one screen exits immediately (`-F`), SGR codes render correctly (`-R`), and the screen is not cleared on exit (`-X`). When `$PAGER` is set, it is invoked verbatim.

### SGR primitives
Shell variables set at the start of `help()` to ANSI/SGR escape sequences, or to empty strings when SGR is suppressed. Names reflect visual role: `BOLD`, `DIM`, `RESET`, and color names (`RED`, `GREEN`, `CYAN`, `YELLOW`, `MAGENTA`). Set to empty when `$NO_COLOR` is set or stdout is not a terminal.

### Help semantic variables
Shell variables that express structural roles in the help text, defined in terms of SGR primitives. `SECTION` styles top-level section headers; `SUBSECTION` styles subsection labels within OPTIONS. Because they reference primitives, zeroing out the primitives (for `NO_COLOR` or non-TTY output) automatically strips all formatting without touching the help text itself.
