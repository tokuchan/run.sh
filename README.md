# run.sh

A single-file POSIX sh tool manager for projects. Wraps a container runtime
(podman or docker) to run containerized commands with your project's mounts,
environment, and packages — requiring nothing beyond `sh`, `git` (or `jj`),
`docker` or `podman`, and `gmake`.

## Quick Start

```sh
# Bootstrap a new project
run --init            # write Dockerfile, flake.nix, and run.conf
$EDITOR flake.nix     # add packages to devShells.default
run make all          # image built automatically on first run

# Daily use
run g++ -o hello hello.cpp
run make test
run --dry-run make all     # preview the full container invocation
run --timeout 60 make ci   # kill and exit 124 if it hangs
```

## Requirements

| Requirement       | Notes                                            |
|-------------------|--------------------------------------------------|
| POSIX sh          | Any POSIX shell: bash, dash, ash, busybox sh     |
| git or jj         | Project root detection                           |
| docker or podman  | Container runtime (auto-detected, prefer podman) |
| gmake             | For the included Makefile; not needed by run.sh  |

No compiled binaries. No package managers at install time. No curl-to-bash.

## Installation

### Option 1 — Copy the script

The simplest approach: copy `run.sh` into your project and commit it.

```sh
curl -fsSL https://raw.githubusercontent.com/tokuchan/run.sh/master/run.sh \
    -o run.sh
chmod +x run.sh
```

### Option 2 — Git submodule

Track `run.sh` as a submodule to pull updates into existing projects:

```sh
# Add the submodule
git submodule add https://github.com/tokuchan/run.sh .run
ln -s .run/run.sh run.sh
git add .run run.sh
git commit -m "chore: add run.sh as submodule"
```

After cloning a repo that uses run.sh as a submodule:

```sh
git clone --recurse-submodules https://github.com/you/yourproject
# or, if already cloned:
git submodule update --init
```

To update run.sh to the latest release:

```sh
git -C .run pull origin master
git add .run
git commit -m "chore: update run.sh"
```

## What It Does

`run.sh` wraps podman or docker to make containerized tools feel native:

- **Path transparency** — CWD and project root are bind-mounted at identical
  absolute paths inside the container. Compiler output, debugger paths, and
  file references are the same on host and inside the container.

- **Stem-based configuration** — mount sets (`.run` files) and environment
  files (`.env` files) are selected by stem (the first positional argument,
  or the symlink name when invoked via symlink). Multiple stems compose via
  `@include`.

- **Auto-build / auto-rebuild** — builds the container image when absent;
  detects `Dockerfile` changes via fingerprint label and rebuilds
  automatically.

- **Nix store on host** — packages are installed at runtime via
  `nix develop --command`; the `/nix` store is shared across runs under
  `$XDG_CACHE_HOME/run/nix/` so images stay thin and package updates don't
  require rebuilding.

- **Bootstrap** — `run --init` writes stub `Dockerfile`, `flake.nix`, and
  `run.conf` without clobbering existing files.

- **Timeout** — `--timeout <secs>` (or `timeout = N` in `run.conf`) kills
  the container after N seconds and exits 124, matching GNU `timeout`
  behavior.

- **Formatted help** — `run --help` is paged through `$PAGER` (falling back
  to `less -FRX` or `more`) with bold/color section headers on TTY output.

## Configuration

Three surfaces, in precedence order (highest first):

1. **CLI flags** — `--runtime`, `--image`, `--timeout`, `--no-tty`, etc.
2. **Environment variables** — `RUN_RUNTIME`, `RUN_IMAGE`, `RUN_TIMEOUT`, etc.
3. **`run.conf`** — `runtime = podman`, `image = myproject:latest`, `timeout = 60`

### Stem files

Resolved relative to the project root (VCS root or directory containing
`run.conf`):

```
default.run   # always loaded first — project-wide mounts
default.env   # always loaded first — project-wide env vars
<stem>.run    # loaded for the matched stem
<stem>.env    # loaded for the matched stem
fs/<stem>/    # host-side mount sources
```

`.run` file format:

```
/absolute/container/path    # bind-mount fs/<stem>/absolute/path here
@include <name>             # load <name>.run and <name>.env recursively
# comment
```

### Symlink dispatch

Creating a symlink to `run.sh` makes the symlink name the stem:

```sh
ln -s run.sh g++
./g++ -o hello hello.cpp    # loads g++.run, g++.env, and fs/g++/
```

## Exit codes

| Code | Meaning                                    |
|------|--------------------------------------------|
| *    | Passes through the container command's exit code |
| 124  | Container exceeded `--timeout` limit       |
| 125  | run.sh configuration or runtime error      |

## Full reference

```sh
run --help
```

## License

MIT — see [LICENSE](LICENSE).
