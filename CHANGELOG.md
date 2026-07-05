# Changelog

All notable changes to run.sh are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions are date codes: `YYYY-MM-DD`.

## [Unreleased]

### Fixed
- `--search` and `--add` no longer bypass the shared nix store mount.
  Both previously called the container runtime directly, skipping the
  `/nix` bind-mount every other invocation gets, so each call re-fetched
  and re-evaluated all of nixpkgs from the network — 3+ minutes and tens
  of thousands of log lines per call. A new `pkg_nix_run()` helper
  (`run.sh` §13.00) now mounts the shared store, mounts a persisted
  eval-cache directory (nix's own SQLite memoization, which doesn't
  survive `--rm` containers otherwise), and passes `nix --quiet` to
  suppress the per-attribute "evaluating '...'" trace nix prints whenever
  stderr isn't a TTY. Repeat searches now take ~5 seconds. A one-time
  warning covers the unavoidable first-use cache warmup so it doesn't
  look like a hang.

## [2026-07-05]

### Added
- `commands/` tree scaffold for the run.sh project itself: `commands/run.conf`,
  `commands/test/main.sh` — `./run.sh test` now runs the full bats suite
  inside the toolchain container, replacing `make test` / `make gate`.
- `.claude/CLAUDE.md` documents the gate command (`./run.sh test`) for the
  `/commit` skill.
- `commands/<cmd>/conf` (or `conf.txt`): per-command settings file, `key =
  value` per line. Recognizes `dispatch = host|container` (default
  `container`) — `host` runs that command's `main.<ext>` directly on the
  host instead of inside the container, exporting `env` vars and
  `RUN_PROJECT`/`RUN_COMMAND`/`RUN_ROOT` into the host process first.
  Inherited root→leaf like other command config. `docs/adr/0017`.
- `RUN_CONTAINER_RUNTIME` (resolved `podman`/`docker` binary) and
  `RUN_CONTAINER_IMAGE` (configured image name) injected as runner metadata
  for every command, host- or container-dispatched — lets a command invoke
  the container manager itself without re-detecting it. Named apart from
  the `--runtime`/`--image` override inputs to avoid collision with a
  nested run.sh-based command's own configuration. Runtime resolution is
  best-effort: empty rather than fatal if neither podman nor docker is
  installed, since most commands don't need it. `docs/adr/0019`.

### Fixed
- Bare invocation (`./run.sh` with no arguments) now appends a best-effort
  command listing after the cheat sheet when a run root can be found,
  instead of showing the cheat sheet alone. README, `CONTEXT.md`, and
  `--help`'s own EXAMPLES already claimed bare invocation lists commands;
  the implementation never did. ADR-0010's no-args safety invariant is
  unchanged — the cheat sheet is still always printed and the process
  still always exits 0 with no side effects regardless of project state;
  the listing is purely additive and silently omitted if no run root is
  found. `docs/adr/0020`.
- `--search`, `--add`, `--remove` (package management) were fully
  implemented and tested but undocumented in both the `usage()` cheat
  sheet and the full `--help` manual; documented in both, plus README.
- `--list-commands` was documented in `--help` but missing from the
  `usage()` cheat sheet and README; added to both.
- `CONTEXT.md`'s "Command help" glossary entry incorrectly claimed
  `--help` with no command path shows a command listing; it never did
  (`--help` is intercepted before project-root detection runs) —
  corrected, and a new "No-args cheat sheet" glossary entry added.
- ADR-0016's Consequences section incorrectly claimed ADR-0010's no-args
  safety invariant was relaxed (that a root `main.<ext>` could run on bare
  invocation); this was never implemented — corrected, see ADR-0020.

### Removed
- `Makefile` — eliminated; `./run.sh test` replaces all targets.
- Root-level `run.conf` — config migrated to `commands/run.conf`.

### Changed
- `README.md`: removed `gmake` dependency; rewrote Quick Start and What It
  Does sections to describe command dispatch; replaced stem-system docs with
  command directory layout; updated examples to `myproject`-style.
- `CONTRIBUTING.md`: removed `make gate` references; updated dev setup to
  `./run.sh test`; requirements now list only `sh`, `git`/`jj`, and a
  container runtime.
- `commands/<cmd>/run`/`run.txt` renamed to `commands/<cmd>/mount`/
  `mount.txt` — no coexistence; a leftover `run`/`run.txt` now exits 125
  pointing at the rename instead of silently dropping its mounts. A line in
  `mount` that isn't a mount spec, comment, or blank is now a hard error
  (exit 125) directing non-mount settings to `conf`, replacing the previous
  warn-and-ignore behavior. `docs/adr/0018`.

### Added (dispatch, carried forward)
- Command directory dispatch: `commands/` tree replaces the stem system. Each
  command is a directory containing `main[.ext]`, `env`, `run`, and `help.md`.
  Greedy longest-match walk selects the deepest matching directory before a flag
  or missing entry stops the traversal.
- Hierarchical config inheritance: `env` and `run` files accumulate root→leaf;
  child values override parent values for the same key.
- `--init-commands` scaffolds the `commands/` skeleton with `.gitignore` and
  `help.md`.
- `--list-commands` lists all available commands with optional tab-separated
  description from `help.md`.
- `RUN_PROJECT`, `RUN_COMMAND`, `RUN_ROOT` injected as environment variables
  into the container.
- `commands/run.conf` is the new project config root (replaces root-level
  `run.conf`).

### Removed
- Stem system (`-s`/`--stem`, `.run`/`.env` stem files, `@include` directives,
  `fs/<stem>/` mount sources) replaced by command directory dispatch.

## [2026-06-24]

### Added
- Auto-paging for `--help`: pipes through `$PAGER` → `less -FRX` → `more` → `cat`
  only when stdout is a TTY
- SGR terminal formatting for `--help` section/subsection headers (bold+cyan
  sections, bold subsections); suppressed when stdout is not a TTY or `NO_COLOR`
  is set
- `--timeout <seconds>` / `RUN_TIMEOUT` / `timeout` in `run.conf`: kills the
  container and exits 124 when the run-time limit is exceeded; `0` means no
  limit (default); implies `--no-tty`
- `README.md`, `CONTRIBUTING.md`: project overview, quick start, git submodule
  usage, contribution guide

## [2026-06-17]

### Added
- `--init` / `--init-container` / `--init-flake` / `--init-config` flags to
  bootstrap a new project (writes `Dockerfile`, `flake.nix`, `run.conf`,
  updates `.gitignore`); never clobbers existing files
- Auto-build: builds container image automatically when absent (opt-out via
  `--no-build`)
- Auto-rebuild: detects stale image via `run.fingerprint` label and rebuilds
  automatically (opt-out via `--no-rebuild`)
- `--force-rebuild`: bypass staleness check and rebuild unconditionally
- `--clean`: remove container image and exit
- `§07` image management section: runtime detection, build/rebuild/clean
  handling, nix store mount — runs before stem resolution
- Nix store mounted from host (`$XDG_CACHE_HOME/run/nix/` shared by default,
  `fs/default/nix/` for hermetic local mode); divorces package management from
  container image lifecycle
- `store = local|shared` three-surface setting (`RUN_STORE`, `--store`)
- `flake.nix` init stub uses `devShells.default` (via `nix develop --command`);
  drops `dockerTools.buildLayeredImage` — packages installed at runtime
- `docs/adr/0008` – `0012`: ADRs for flake-as-sole-specifier, dry-run
  immutability, no-args safety, nix-store-on-host, XDG shared store
- `--search <term>`: runs `nix search nixpkgs <term>` inside the container
  to discover package attribute paths; exits after printing results
- `--add <pkg>`: validates package via `nix eval`, inserts above `# run:packages`
  sentinel in `flake.nix`; idempotent; prints pre-warm hint; repeatable
- `--remove <pkg>`: deletes package line from `flake.nix`; idempotent
- `docs/adr/0013`: sentinel comment as insertion anchor for `--add`/`--remove`

## [2026-06-15]

### Added
- `run.sh` — single-file POSIX sh container runner with §NN section markers
  and embedded vim navigation howto (`cnoreabbrev ss §`)
- §01 help/usage: no-args cheat sheet; `--help` full manual with log format
  recipes and POSIX tool examples
- §02 logging: structured `TIMESTAMP [SEVERITY] run: MESSAGE [JSON]` to stderr;
  verbosity levels controlled by `-v`/`-q`
- §03 configuration: `run.conf` KEY=VALUE parsing with strict unknown-key
  rejection; three-surface settings (CLI > env var > config key)
- §04 run root detection: `jj root` → `git rev-parse --show-toplevel` →
  walk-up from CWD; `--project-root` override
- §05 stem resolution: symlink dispatch (`basename $0`) → first positional arg;
  `parse_run_file` with `@include` support; `parse_env_file`; `load_explicit_stems`
- §06 mount construction: CWD + project root mirrored at same absolute paths;
  `--mirror`/`--mirror-ro` for arbitrary path mirroring; `--no-cwd` to suppress
- §08 runtime detection: podman → docker auto-detect; UID mapping via
  `--userns=keep-id` (podman) or `--user uid:gid` (docker)
- §09 container invocation: `--entrypoint bash -c '"$@"' --` for correct
  word-boundary preservation; exit code propagated verbatim; `--dry-run` mode
- `Makefile` with `help` (default), `test`, `gate`, `setup` targets
- `tests/` bats test suite: 27 tests covering help, config, env/run file
  parsing, stem resolution, CWD mirrors, and exit code propagation
- `CONTEXT.md` domain glossary (stem, mount-set, env-set, run root, load order,
  config hierarchy, log format, etc.)
- `docs/adr/` — 7 ADRs: function layout, stem atomicity, reversible flags,
  UID mapping, three-surface settings, log format, script navigation

[Unreleased]: https://github.com/tokuchan/run.sh/compare/2026-06-24...HEAD
[2026-06-24]: https://github.com/tokuchan/run.sh/compare/2026-06-17...2026-06-24
[2026-06-17]: https://github.com/tokuchan/run.sh/compare/2026-06-15...2026-06-17
[2026-06-15]: https://github.com/tokuchan/run.sh/releases/tag/2026-06-15
