# ADR 0002: Stem is the atomic unit of configuration

## Status
Superseded by ADR-0016

## Context
`run.sh` needs to associate bind mounts, environment variables, and (via `@include`) transitive dependencies with a given invocation context. These could be configured independently (separate include mechanisms per file type), or treated as a single logical unit.

## Decision
The stem is the atomic unit. Every configurable artifact — `.run` files, `.env` files, `fs/<stem>/` directories — is selected by the same stem resolution. `@include <name>` inside a `.run` file loads both `<name>.run` and `<name>.env` as a single operation. There is no mechanism to include just the mounts or just the env of a stem without the other.

The reserved `default` stem is always loaded first, providing project-wide baseline configuration. Any stem that doesn't need specialization beyond the default needs no config files at all.

## Consequences
- Mount and env configuration for a tool context are always colocated and versioned together.
- Adding a new tool context requires creating only one stem name, not coordinating across two file types.
- It is impossible to mix mounts from stem A with env vars from stem B without creating a third stem that `@include`s both.
