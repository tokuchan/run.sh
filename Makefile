.POSIX:
.DEFAULT_GOAL := help

# Auto-detect container runtime (podman preferred, docker fallback).
RUNTIME != command -v podman 2>/dev/null || command -v docker 2>/dev/null

# ─────────────────────────────────────────────────────────────
# help — list available targets (default)
# ─────────────────────────────────────────────────────────────
help:
	@printf 'run.sh — containerized command runner\n\n'
	@printf 'Usage: make <target>\n\n'
	@printf 'Targets:\n'
	@printf '  %-20s %s\n' 'help'   'Show this help (default)'
	@printf '  %-20s %s\n' 'setup'  'Build toolchain container image from Dockerfile'
	@printf '  %-20s %s\n' 'test'   'Run the bats test suite (via run.sh inside container)'
	@printf '  %-20s %s\n' 'gate'   'Alias for test (used by /commit pre-commit hook)'
	@printf '\n'
	@printf 'Run '\''./run.sh --help'\'' for the full run.sh manual.\n'
	@printf 'Runtime: %s\n' '$(RUNTIME)'

# ─────────────────────────────────────────────────────────────
# setup — build the toolchain container image from Dockerfile
# ─────────────────────────────────────────────────────────────
setup:
	$(RUNTIME) build -t run-toolchain:latest .

# ─────────────────────────────────────────────────────────────
# test / gate — run the bats test suite
# After 'make setup', this uses run.sh to run bats inside the container.
# Before setup, falls back to host bats if available.
# ─────────────────────────────────────────────────────────────
test:
	./run.sh bats tests/

gate: test

.PHONY: help setup test gate
