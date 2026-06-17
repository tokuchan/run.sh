# Help pager and SGR formatting for --help output

`run --help` produces ~110 lines of text that grows as flags are added.
Two improvements were considered together: auto-paging through `less`/`more`,
and SGR terminal formatting for visual structure.

## Pager

Detection chain: `$PAGER` (user preference) → `less -FRX` → `more` → `cat`.
Paging is suppressed when stdout is not a terminal (piped output).

`less -FRX` defaults: exit immediately if content fits on one screen (`-F`);
render SGR codes rather than showing escape characters (`-R`); do not clear the
screen on exit (`-X`). These flags are only applied when `less` is selected
directly — when `$PAGER` is set it is invoked verbatim.

No `--no-pager` flag is added. `PAGER=cat run --help` is the established Unix
idiom and sufficient for scripting contexts.

## SGR formatting

Three approaches were considered:

1. **Direct embedding** — write `\033[1;36m` escape codes inline in the heredoc.
   Works, but couples visual style to help text; every edit must touch escape
   sequences; breaks piped output unless guarded.

2. **Groff/man-page rendering** — write help as troff/mdoc markup and render via
   `groff`. Semantically correct but requires `groff` on the host (not a safe
   assumption) and is a substantial authoring overhead for a single-file script.

3. **Two-layer shell variables** — SGR *primitive* variables (`BOLD`, `CYAN`,
   `RESET`, …) are set to escape sequences or empty strings at the start of
   `help()`. *Semantic* variables (`SECTION`, `SUBSECTION`) are defined in terms
   of primitives. The help heredoc references only semantic variables.

Option 3 is chosen. Zeroing out the primitives (for `NO_COLOR` or non-TTY
output) strips all formatting without touching the help text. Semantic names
(`SECTION`, `SUBSECTION`) make the heredoc readable and the intent of each
styled element explicit. Changing the color scheme requires editing only the
primitive-to-semantic mapping, not every styled line.

## SGR suppression

SGR is suppressed when either:
- stdout is not a terminal (`[ -t 1 ]` is false), or
- `$NO_COLOR` is set to any value (per nocolor.org convention).

Paging is suppressed only when stdout is not a terminal. `NO_COLOR` does not
suppress paging — a user may want paginated plain-text output.

## Color choices

`SECTION = ${BOLD}${CYAN}` — bold cyan for top-level headers (`NAME`,
`OPTIONS`, `EXAMPLES`, …). Cyan is readable on both dark and light terminals.

`SUBSECTION = ${BOLD}` — bold only for subsection labels within `OPTIONS`
(`Stem selection:`, `Image management:`, …). Subordinate to section headers
without competing color.
