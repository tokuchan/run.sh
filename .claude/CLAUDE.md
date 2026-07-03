# run.sh project — Claude Code instructions

## Gate command

The pre-commit gate is:

```sh
./run.sh test
```

This runs the full bats test suite inside the toolchain container.
No `make` or separate test runner install is required — the container
provides everything.
