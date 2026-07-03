Run the full bats test suite inside the toolchain container.

All tests in tests/ are executed. The container image is built automatically
if absent. Exit code passes through from bats (0 = all pass, non-zero = failures).
