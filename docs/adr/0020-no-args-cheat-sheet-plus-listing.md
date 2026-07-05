# ADR 0020: No-args invocation appends a best-effort command listing after the cheat sheet

## Status
Accepted. Extends ADR-0010. Corrects a stray claim in ADR-0016's Consequences (see Context).

## Context
ADR-0010 established an unconditional invariant: bare `run.sh` (zero arguments) always prints the short `usage()` cheat sheet and exits 0, with no side effects and no dependency on project state. The implementation enforced this literally — `main()` special-cased `$# -eq 0` to call `usage()` and exit before any project-root detection or command dispatch ran at all.

This turned out to be a worse experience than intended. Three other places in the project independently documented (or assumed) that bare invocation lists available commands: the README Quick Start (`./myproject  # list available commands`), the `CONTEXT.md` "Command listing" glossary entry (which described the no-subcommand case as producing the auto-generated listing), and `--help`'s own EXAMPLES section (`myproject  # show available commands`). None of that was true — the cheat-sheet shortcut never reached `show_command_listing`, so a project with real commands under `commands/` (like this one, with `hello` and `test`) never showed them on bare invocation. Users reported this as "commands are available but they don't show."

Separately, ADR-0016's Consequences section claims "ADR-0010's no-args safety invariant is relaxed: `commands/main.<ext>` may run with side effects when the runner is invoked with no arguments." This was never implemented — `main()`'s zero-arg shortcut ran (and still runs) before `dispatch_command` is ever called, so a root-level `main.<ext>` could never execute via bare invocation. That bullet was aspirational and is corrected by this ADR: it does not reflect current or intended behavior.

## Decision
Bare invocation keeps ADR-0010's invariant intact — the cheat sheet is always printed and the process always exits 0, regardless of project state — and adds one thing after it: a best-effort command listing.

```sh
if [ $# -eq 0 ]; then
    usage
    if find_run_root 2>/dev/null; then
        printf '\n'
        show_command_listing "$RUN_RUN_ROOT/commands"
    fi
    exit 0
fi
```

- `usage()` always runs first and unconditionally, exactly as ADR-0010 requires. Nothing about the cheat sheet's content, guarantees, or unconditional nature changes.
- `find_run_root` is then attempted purely for its read-only side: locating `commands/run.conf`. Its own error logging is suppressed (`2>/dev/null`) here specifically, since failure is an expected, non-error outcome in this best-effort path — the cheat sheet has already satisfied the "always show something useful" requirement.
- If a run root is found, `show_command_listing` (the same function used for any command path with no `main.<ext>`) prints the top-level listing. This is read-only: it lists directory entries and reads `help.md` first lines. No image build, no container launch, no file writes.
- If no run root is found (e.g. a freshly copied, not-yet-`--init`'d script), the cheat sheet is shown alone, exit 0, no error — the invariant holds exactly as before for that case.
- `commands/main.<ext>` (a root-level main) is still never invoked by bare invocation — the zero-arg branch returns before `dispatch_command` runs, same as pre-ADR-0020. The ADR-0016 bullet describing this as possible was incorrect and is superseded by this decision.

## Alternatives considered

**Make bare invocation dispatch normally (drop the zero-arg special case entirely).** This is what the README/CONTEXT.md/EXAMPLES text implied and is closest to what ADR-0016's stray bullet described. Rejected: it reintroduces exactly the failure mode ADR-0010 was written to prevent — a project with a root-level `commands/main.<ext>` would run it, with whatever side effects it has, the moment someone runs the bare command to see what's available. It also makes the zero-arg path fail loudly (exit 125) for a freshly copied script with no run root yet, which is a worse first-run experience than a cheat sheet.

**Only show the listing, drop the cheat sheet.** Rejected per explicit product direction: the cheat sheet's common-options summary is useful on every invocation, independent of whether a project has commands configured yet (e.g. immediately after `cp run.sh myproject`, before `--init`).

**Fold the listing into `usage()` itself.** Rejected: `usage()` is a static, dependency-free string (a `cat <<'EOF'`) by design — mixing in a dynamic, project-dependent section would complicate its one job and blur the line between "always-true reference text" and "what this project happens to have right now."

## Consequences
- README, `CONTEXT.md`, and `--help`'s EXAMPLES section were updated to describe the actual combined behavior ("cheat sheet, then available commands") instead of the previously-inaccurate "list available commands."
- `CONTEXT.md` gained a "No-args cheat sheet" glossary entry distinguishing this behavior from `--help` (full manual, no listing, intercepted before root detection even runs) and `--list-commands` (recursive, machine-readable, no cheat sheet).
- ADR-0016's Consequences bullet about the no-args invariant being relaxed no longer applies and should be read as historical/superseded by this ADR.
- `tests/01_help.bats` gained fixture-isolated cases for both branches (run root found vs. not found) instead of relying on incidentally picking up this repository's own `commands/` tree.
