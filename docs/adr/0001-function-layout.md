# ADR 0001: Organize run.sh with named functions; help first

## Status
Accepted

## Context
`run.sh` is a single-file POSIX sh script intended to be inspected by users before running (`cat run.sh`). As the script grows it needs internal structure to remain navigable.

## Decision
Organize all logic into named shell functions. Place the `usage` (cheat-sheet) and `help` (full manual) functions at the top of the file, immediately after the shebang and any header comment, so they are the first thing a reader sees when paging or catting the file. All other functions follow in a logical reading order beneath them.

## Consequences
- Users who `cat` the script before running it see the help text immediately — no scrolling required.
- Functions are callable in unit-test harnesses without executing the main body.
- POSIX sh does not hoist function definitions, so the `main` call must appear at the bottom of the file after all function definitions.
