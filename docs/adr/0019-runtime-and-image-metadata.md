# ADR 0019: RUN_CONTAINER_RUNTIME and RUN_CONTAINER_IMAGE injected as runner metadata

## Status
Accepted.

## Context
Host-dispatched commands (ADR-0017) exist specifically for cases where a command needs to drive a container runtime itself — managing a sibling container, avoiding docker-in-docker. Until now, such a command had to re-detect podman vs. docker on its own, duplicating `detect_runtime`'s auto-detect logic, and had no reliable way to know which image the project is configured to use.

## Decision
Extend the existing runner metadata (`RUN_PROJECT`, `RUN_COMMAND`, `RUN_ROOT`) with two more read-only variables, injected unconditionally for every command regardless of dispatch target:

- `RUN_CONTAINER_RUNTIME` — the resolved runtime binary name (`podman` or `docker`).
- `RUN_CONTAINER_IMAGE` — the configured image name (empty if `image` isn't set in `run.conf`).

Both flow through the same `set_env` mechanism as the other metadata, so they can't be overridden by a command's own `env` file, and both are visible in `--dry-run` output like any other injected var.

**Naming, not `RUN_RUNTIME`/`RUN_IMAGE`:** those exact names are already the three-surface override inputs for run.sh's own runtime/image selection (`--runtime`/`RUN_RUNTIME`/`runtime =`, `--image`/`RUN_IMAGE`/`image =`). Reusing them for the injected metadata was tried first and caused a real bug during implementation: this project's own `commands/test` (container-dispatched) got `RUN_RUNTIME=podman` injected into its container's environment; bats then ran inside that container, and every nested `"$RUN_SH" ...` call the test suite makes inherited that ambient `RUN_RUNTIME`, so `defaults()`'s `RUN_RUNTIME="${RUN_RUNTIME:-}"` treated it as an explicit override and skipped auto-detection entirely — silently invalidating any test that tried to simulate "no runtime installed". The same collision would hit any real host-dispatched command that shells out to another run.sh-based project: the outer project's resolved runtime/image would silently become the inner project's override. `RUN_CONTAINER_RUNTIME`/`RUN_CONTAINER_IMAGE` are deliberately distinct names so a nested run.sh invocation never mistakes this metadata for its own configuration input — the same reasoning that already keeps `RUN_ROOT` (output) distinct from `RUN_PROJECT_ROOT` (input).

**Non-fatal detection:** `detect_runtime` is now called unconditionally, before dispatch decides host vs. container, so the metadata is available either way. Previously it only ran on the container path, where finding no runtime is genuinely fatal. A host-dispatched command has never had any dependency on podman/docker being installed — plenty of host commands have nothing to do with containers at all — so making detection failure fatal here would be a new, unwanted requirement. `detect_runtime` was refactored to fail silently (return 1, no log) and let the two existing call sites (container dispatch, `--clean`/package management) log the "no container runtime found" error and exit 125 themselves, since those are the places where it's actually fatal. For metadata injection, failure just leaves `RUN_CONTAINER_RUNTIME`/`RUN_CONTAINER_IMAGE` empty; a command that tries to use an empty value gets its own clear failure when the shell tries to run "" as a command.

## Consequences
- A host-dispatched command can now do `"$RUN_CONTAINER_RUNTIME" run "$RUN_CONTAINER_IMAGE" ...` without caring which runtime is installed.
- `RUN_CONTAINER_RUNTIME`/`RUN_CONTAINER_IMAGE` are reserved names in `commands/<cmd>/env`, same as the other three metadata vars.
- `detect_runtime`'s error logging moved from the function itself to its two fatal call sites — the function is now a pure "resolve or silently fail" primitive.
