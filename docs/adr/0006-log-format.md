# ADR 0006: Structured log format with inline JSONL diagnostic object

## Status
Accepted

## Context
`run.sh` emits operational messages (mount conflicts, dry-run previews, errors). These must be human-readable on a terminal and machine-parseable with standard POSIX tools, without requiring a dedicated log parser.

## Decision
All `run.sh`-generated log lines follow this format:

```
TIMESTAMP [SEVERITY] run: MESSAGE [JSON]
```

Example:
```
2026-06-15T13:31:25Z [WARN ] run: CWD conflicts with .run mount, CWD wins {"mount":"/home/sean/proj","source":"cwd","displaced":"default.run"}
```

Fields:
- **TIMESTAMP**: ISO 8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`)
- **SEVERITY**: fixed-width 5-char bracket — `[DEBUG]`, `[INFO ]`, `[WARN ]`, `[ERROR]`
- **`run:`**: literal prefix, always present — makes run.sh lines greppable in mixed output
- **MESSAGE**: human-readable text, never contains a bare `{`
- **JSON**: optional trailing `{...}` object with diagnostic key-value pairs

All log output goes to **stderr**. Stdout carries only the container's own stdout.

Verbosity levels (controlled by `-v`/`-q`, `RUN_VERBOSE`, `verbose` config key):
| Level | Shows |
|---|---|
| `-q` (quiet) | `[ERROR]` only |
| default | `[WARN]` and `[ERROR]` |
| `-v` | `[INFO]`, `[WARN]`, `[ERROR]` |
| `-vv` | `[DEBUG]` and all above |

## POSIX tool recipes (documented in `--help` output)

```sh
# Filter by severity
run.sh ... 2>&1 | grep '\[ERROR\]'
run.sh ... 2>&1 | grep '\[WARN \]'

# Extract timestamps only
run.sh ... 2>/tmp/run.log; cut -d' ' -f1 /tmp/run.log

# Extract structured JSON diagnostics
run.sh ... 2>&1 | grep -oE '\{[^}]*\}'

# Pretty-print diagnostics (requires jq)
run.sh ... 2>&1 | grep -oE '\{[^}]*\}' | jq .

# Strip JSON to get clean human messages
run.sh ... 2>&1 | sed 's/ {[^}]*}$//'
```

## Consequences
- Stdout is always clean container output — safe for pipelines.
- Stderr carries all run.sh diagnostics, structured and filterable without extra tooling.
- Every new log call must include a JSON object when it has machine-useful values (paths, counts, flags); omit JSON for pure status messages.
- `--dry-run` output follows the same format (severity `[INFO ]`), making it greppable too.
