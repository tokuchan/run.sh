# ADR 0004: UID/GID mapping for container-local indistinguishability

## Status
Accepted

## Context
Files written inside the container via bind mounts must appear on the host owned by the invoking user, and tools inside the container must behave as if run by that user. Without UID mapping, files are created as root (or container-image user), breaking host-side workflows.

## Decision
Apply runtime-specific UID mapping:

- **Podman**: `--userns=keep-id` — maps host UID/GID into the container transparently. The in-container user has the same numeric UID/GID as the host user, and `/etc/passwd` is rewritten by podman to match. Cleanest option.
- **Docker**: `--user $(id -u):$(id -g)` — runs the container process as the host UID/GID. Files on bind mounts are correctly owned on the host, but the UID may not have an entry in the container's `/etc/passwd`, which can cause `getpwuid()` failures in tools that look up the current user by UID.

## Consequences
- Podman is the preferred runtime for this use case. Docker support is best-effort.
- Container images intended for use with `run.sh` under Docker should ensure the expected UID has a passwd entry, or tolerate missing passwd entries gracefully.
- A future option (`--no-uid-map`) allows opting out for containers where the image manages its own user setup.
