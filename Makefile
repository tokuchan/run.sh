.POSIX:
.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────
# help — list available targets (default)
# ─────────────────────────────────────────────────────────────
help:
	@printf 'run.sh — containerized command runner\n\n'
	@printf 'Usage: make <target>\n\n'
	@printf 'Targets:\n'
	@printf '  %-20s %s\n' 'help'   'Show this help (default)'
	@printf '  %-20s %s\n' 'test'   'Run the bats test suite'
	@printf '  %-20s %s\n' 'gate'   'Alias for test (used by /commit)'
	@printf '  %-20s %s\n' 'setup'  'Pull/build the project toolchain container'
	@printf '\n'
	@printf 'Run '\''run.sh --help'\'' for the full run.sh manual.\n'

# ─────────────────────────────────────────────────────────────
# test / gate — run the bats test suite
# ─────────────────────────────────────────────────────────────
test:
	bats tests/

gate: test

# ─────────────────────────────────────────────────────────────
# setup — pull/build the project toolchain container via Nix flake
# (populated once the flake.nix is written)
# ─────────────────────────────────────────────────────────────
setup:
	@printf 'setup: flake.nix not yet written — run.sh dogfooding coming soon\n'

.PHONY: help test gate setup
