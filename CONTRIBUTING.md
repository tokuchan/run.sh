# Contributing to run.sh

## Design principles

**Single file, zero install-time dependencies.** `run.sh` is intentionally a
single POSIX sh script. No compiled helpers, no bootstrap installers, no
runtime dependencies beyond the shell itself. PRs that add helper binaries or
shell-out to language runtimes at startup will be declined.

**POSIX sh only.** No bashisms. The script must run under `dash`, `ash`, and
`bash`. When in doubt, test with `dash run.sh` or add a shellcheck directive
and explain why the exception is justified.

**ADR-first for structural changes.** If your change affects a decision
documented in `docs/adr/`, read that ADR and reference it in your PR. If your
change creates a new trade-off worth recording, propose a new ADR as part of
the PR.

**Test-driven.** Every new behavior gets a test written first. See the
workflow below.

## Development setup

With Nix (recommended):

```sh
git clone https://github.com/tokuchan/run.sh
cd run.sh
nix develop          # enters devShell with bats, shellcheck, etc.
make gate            # run the full test suite
```

Without Nix:

```sh
# Debian/Ubuntu
apt-get install bats shellcheck
# macOS
brew install bats-core shellcheck

make gate
```

## Test-driven workflow

New features and fixes are implemented test-first:

1. Write a `@test` block in `tests/` — confirm it fails (RED)
2. Write minimal code in `run.sh` to pass the test (GREEN)
3. Commit: one commit per behavior, using `make gate` before each commit

Each `@test` tests observable behavior through `run.sh`'s public interface.
Do not test internal functions directly. See `tests/` for existing patterns
and `tests/helpers/setup.bash` for available fixtures (`setup_fake_runtime`,
`write_run_conf`, etc.).

The gate must pass before any commit:

```sh
make gate    # runs all bats tests
```

## Commit format

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

**Changelog entries are required for `feat` and `fix` commits.** Add an entry
under `## [Unreleased]` in `CHANGELOG.md` before committing.

## Filing issues

Please include:

- The `run.sh` version (first line of the script, or `git log -1 --oneline`)
- Your `run.conf` (with secrets removed)
- Full stderr output with the `-v` flag
- Container runtime and version (`podman --version` or `docker --version`)
