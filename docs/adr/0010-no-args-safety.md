# run.sh with no arguments must always be safe and show help

Invoking `run.sh` with no arguments must always print the short cheat-sheet help and exit 0. It must never modify files, build images, launch containers, or produce any side effect. This is an unconditional invariant — it holds regardless of project state, whether the image exists, or what `run.conf` contains.

This matters because `run.sh` is often the first thing a new contributor runs in an unfamiliar project. A tool that does something destructive or slow when invoked bare is hostile. The invariant also means the no-args path is trivially safe to run in CI health checks, shell completions, and documentation generators. Users who want to see the full manual use `--help`.

Extended by ADR-0020: a best-effort, read-only command listing is now appended after the cheat sheet when a run root can be found. That addition does not weaken any guarantee above — the cheat sheet is still always printed, the process still always exits 0, and nothing here becomes conditional on project state; the listing is purely additive.
