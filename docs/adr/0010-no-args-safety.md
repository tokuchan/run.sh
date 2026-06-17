# run.sh with no arguments must always be safe and show help

Invoking `run.sh` with no arguments must always print the short cheat-sheet help and exit 0. It must never modify files, build images, launch containers, or produce any side effect. This is an unconditional invariant — it holds regardless of project state, whether the image exists, or what `run.conf` contains.

This matters because `run.sh` is often the first thing a new contributor runs in an unfamiliar project. A tool that does something destructive or slow when invoked bare is hostile. The invariant also means the no-args path is trivially safe to run in CI health checks, shell completions, and documentation generators. Users who want to see the full manual use `--help`.
