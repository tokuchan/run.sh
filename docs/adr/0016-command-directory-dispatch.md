# ADR 0016: Command directory dispatch replaces the stem system

## Status
Accepted. Supersedes ADR-0002.

## Context
The stem system (ADR-0002) used flat files (`<stem>.run`, `<stem>.env`, `fs/<stem>/`) at the run root to associate mount configuration and environment variables with an invocation context. Composition was handled by `@include` directives inside `.run` files. The stem was also the first word of the forwarded command, coupling configuration selection to command routing.

This design had two friction points. First, there was no natural place to put command-specific artifacts (scripts, help text, sub-command groupings) — they had to live alongside the stem files in a flat namespace. Second, `@include` chains had to be maintained manually; adding a new tool context required understanding the existing include graph.

The goal of this redesign is to make the project structure self-organising: the filesystem hierarchy should encode both the command routing and the configuration composition, eliminating the need for explicit include directives.

## Decision
Replace the stem system with a **command directory** model.

### Structure
A `commands/` directory at the run root holds the entire command tree. Each subdirectory is a command. A command directory may contain:

- `main.<ext>` — the program to run (probe order: `main`, `main.py`, `main.nu`, `main.sh`, `main.rb`, `main.js`, `main.pl`)
- `run` or `run.txt` — bind-mount configuration (same line-based format as the former `.run` files, minus `@include`)
- `env` or `env.txt` — environment variables (same `KEY=VALUE` format as the former `.env` files)
- `fs/` — host-side mount sources
- `help.md` or `help.txt` — user-facing documentation; first paragraph is the short description

`commands/run.conf` is the project config file and the run root marker. Its presence is what `find_run_root` looks for (replacing the old `run.conf` at the project root). `Dockerfile` and `flake.nix` remain at the run root — both tools expect to be invoked from the directory that contains them.

### Command dispatch
The runner (`basename $0`) consumes its own options greedily from the front of the argument list. The first non-option token begins a greedy longest-match walk into `commands/`. The walk stops at the first token that starts with `-` or has no matching child directory. Everything remaining is forwarded to `main.<ext>` as arguments. `--` explicitly switches to command-path mode.

If no `main.<ext>` is found in the matched directory, the runner auto-generates a command listing (shallow, with first sentence of each child's help file). This applies at any depth, including the top level.

### Configuration composition
Configuration is loaded from the command tree root down to the matched command directory, in order. Mount specs accumulate; env var conflicts and mount destination conflicts resolve last-wins (deepest directory wins). This is the composition graph — no `@include` directives exist or are needed.

`commands/.gitignore` contains `**/fs/` to automatically protect `fs/` directories at any depth.

### Runner metadata
The runner injects three read-only env vars into every container invocation: `RUN_PROJECT` (resolved project name), `RUN_COMMAND` (slash-separated command path), `RUN_ROOT` (absolute run root path). These cannot be overridden by `commands/env` files.

### Project name resolution
The expected project name is the `name` key in `commands/run.conf` if present, otherwise `basename` of the run root directory. If `basename $0` does not match, a `[WARN]` is emitted. `name` is a `run.conf`-only setting with no CLI or env var surface — the one intentional exception to the three-surface rule (ADR-0005). It is a declaration of project identity, not a runtime tunable.

## Alternatives considered

**Keep the stem system, add a `commands/` overlay.** The stem files would remain for configuration; a `commands/` directory would add script dispatch on top. Rejected: two parallel systems with overlapping concerns, and `@include` complexity remains.

**Flat `commands/` without hierarchical config.** Each command directory would be fully self-contained — no inherited `run`/`env` from parent directories. Rejected: forces duplication when multiple sub-commands share mounts or env vars (the problem `@include` existed to solve).

**Keep `run.conf` at the project root.** The run root marker stays at the top level; only script dispatch moves into `commands/`. Rejected: leaves configuration split across two locations. Putting `run.conf` inside `commands/` means everything except the runner, `Dockerfile`, and `flake.nix` lives in one subtree.

## Consequences
- ADR-0002 (stem as atomic unit) is superseded. The Command is the new atomic unit.
- ADR-0010's no-args safety invariant is relaxed: `commands/main.<ext>` may run with side effects when the runner is invoked with no arguments. Project authors control the no-args experience; the auto-generated listing is the safe fallback when no `main.<ext>` exists.
- ADR-0005's three-surface rule has one exception: `name` in `run.conf`.
- The `--stem` / `-s` flag, the `stems` `run.conf` key, and all `@include` handling are removed.
- Existing projects using the stem system must migrate to the command directory layout. No coexistence mode is provided.
