# Changelog

All notable changes to run.sh are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions are date codes: `YYYY-MM-DD`.

## [Unreleased]

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

[Unreleased]: https://github.com/example/run/compare/2026-06-15...HEAD
[2026-06-15]: https://github.com/example/run/releases/tag/2026-06-15
