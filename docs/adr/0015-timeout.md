# Run-time limit (--timeout)

`--timeout <seconds>` sets a maximum wall-clock duration for the container
command. When the limit is exceeded, run.sh stops the container and exits 124.

## Scope

Timeout applies to the container run only — not to auto-build or auto-rebuild.
Build operations (layer pulls, Nix evaluation) have their own latency profiles
and are better left unconstrained; a separate flag can address them if needed.

## Format

Integer seconds. `0` means no timeout (the default). This matches `ulimit`
and similar Unix conventions. No human-readable suffix parsing (`30s`, `1m`)
to keep the POSIX sh implementation minimal.

## Exit code: 124

124 matches GNU `timeout(1)`. It is distinct from application error codes,
from run.sh's own `125`, and from signal exits (128+N). Scripts that check
`$?` for timeout can use the same constant regardless of whether the underlying
mechanism is GNU `timeout` or run.sh's own timer.

## Implementation: named container + docker wait + background timer

run.sh may only assume POSIX sh, git, GNU make, and docker/podman on the host.
The POSIX sh `wait` built-in can wait for a single PID but cannot wait for
"whichever of two processes exits first" without polling. Three alternatives
were considered:

1. **`timeout(1)` from coreutils** — not guaranteed on the host; rejected.
2. **Background `docker run` + foreground polling loop** — requires `wait -n`
   (bash-only) or a busy-poll sleep loop; rejected.
3. **Named container + `docker run -d` + `docker logs -f` + `docker wait` +
   background sleep timer** — fully POSIX sh, clean separation of concerns.
   Chosen.

The mechanism:
- Container is started detached (`docker run -d --name run-$$`).
- `docker logs -f` streams output to the terminal in the foreground.
- A background subshell sleeps for the timeout duration, then calls
  `docker stop <name>` and writes a sentinel temp file.
- The shell calls `docker wait <name>`, which blocks until the container exits
  (either normally or because the timer called `docker stop`).
- After `docker wait` returns, run.sh checks for the sentinel file to
  distinguish timeout from normal exit.

## TTY: implied --no-tty

`docker run -d` (detached) is incompatible with `-t` (allocate a PTY). Timeout
therefore implies `--no-tty`. If `--tty` and `--timeout` are both set, run.sh
emits a warning and proceeds without a TTY. This is not a significant
constraint: the primary use case for timeout is non-interactive commands (test
suites, builds, scripts that might hang) where TTY is irrelevant.

## Termination: docker stop

`docker stop` sends SIGTERM and waits for the container's default grace period
(10 s) before escalating to SIGKILL. This gives well-behaved processes a chance
to flush output and clean up. `docker kill` (immediate SIGKILL) was considered
but rejected as too aggressive for a dev tool.

## Override: --timeout 0

`timeout = 60` in `run.conf` can be overridden for a single invocation with
`--timeout 0`. This follows the three-surface setting pattern (CLI > env var >
run.conf) without needing a separate `--no-timeout` flag.

## Dry-run

`--dry-run` includes `timeout: Xs` in the resolved invocation summary, making
it inspectable without executing.
