# run.sh project — Claude Code instructions

## Running tests

**Always** run the test suite via:

```sh
./run.sh test
```

Never run `bats` directly. The authoritative test environment is the
toolchain container — `./run.sh test` is the only correct way to verify
the suite, both during development and before committing.

## Gate command

The pre-commit gate is `./run.sh test`. Run it before every commit.
