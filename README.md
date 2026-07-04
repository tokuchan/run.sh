# run.sh

A single-file POSIX sh tool manager for projects. Wraps a container runtime
(podman or docker) to run containerized commands with your project's mounts,
environment, and packages — requiring nothing beyond `sh`, `git` (or `jj`),
and `docker` or `podman`.

## Quick Start

```sh
# Bootstrap a new project
cp run.sh myproject          # rename to match your project
chmod +x myproject
./myproject --init           # write Dockerfile, flake.nix, commands/run.conf
$EDITOR flake.nix            # add packages to devShells.default
$EDITOR commands/run.conf    # set image = myregistry/myimage:latest

# Add a command
mkdir -p commands/build
printf '#!/bin/sh\nexec make "$@"\n' > commands/build/main.sh
chmod +x commands/build/main.sh

# Daily use
./myproject build            # image built automatically on first run
./myproject release package --arch=arm64
./myproject --dry-run build  # preview the full container invocation
./myproject                  # list available commands
```

## Requirements

| Requirement       | Notes                                            |
|-------------------|--------------------------------------------------|
| POSIX sh          | Any POSIX shell: bash, dash, ash, busybox sh     |
| git or jj         | Project root detection                           |
| docker or podman  | Container runtime (auto-detected, prefer podman) |

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

`run.sh` wraps podman or docker to make containerized commands feel native:

- **Command dispatch** — commands live in a `commands/` directory tree at
  the project root. Each subdirectory is a command; `commands/build/main.sh`
  runs when you invoke `./myproject build`. Sub-commands nest naturally:
  `./myproject release package` dispatches to `commands/release/package/`.

- **Greedy longest match** — the dispatcher walks directory tokens from the
  argument list until a flag or missing directory stops it. Remaining
  arguments are forwarded verbatim to `main.<ext>`.

- **Path transparency** — CWD and project root are bind-mounted at identical
  absolute paths inside the container. Compiler output, debugger paths, and
  file references are the same on host and inside the container.

- **Per-command configuration** — each command directory may have an `env`
  file (KEY=VALUE pairs), a `mount` file (bind-mount specs), and a `conf`
  file (per-command settings). Configuration accumulates root→leaf; child
  values override parent values for the same key. `RUN_PROJECT`,
  `RUN_COMMAND`, and `RUN_ROOT` are always injected.

- **Host dispatch** — a command normally runs inside the container, but
  setting `dispatch = host` in its `conf` file runs `main.<ext>` directly on
  the host instead — for commands that must drive another container runtime
  or otherwise can't run nested. `env` vars and `RUN_PROJECT`/`RUN_COMMAND`/
  `RUN_ROOT` are still exported into the host process; mounts, image
  management, and `--timeout` don't apply and are skipped.

- **Auto-build / auto-rebuild** — builds the container image when absent;
  detects `Dockerfile` changes via fingerprint label and rebuilds
  automatically.

- **Nix store on host** — packages are installed at runtime via
  `nix develop --command`; the `/nix` store is shared across runs under
  `$XDG_CACHE_HOME/run/nix/` so images stay thin and package updates don't
  require rebuilding.

- **Bootstrap** — `./myproject --init` writes stub `Dockerfile`, `flake.nix`,
  `commands/run.conf`, and a `commands/` skeleton without clobbering
  existing files.

- **Timeout** — `--timeout <secs>` (or `timeout = N` in `commands/run.conf`)
  kills the container after N seconds and exits 124, matching GNU `timeout`
  behavior.

- **Formatted help** — `./myproject --help` is paged through `$PAGER`
  (falling back to `less -FRX` or `more`) with bold/color section headers
  on TTY output. Per-command help comes from `commands/<cmd>/help.md`.

## Configuration

Three surfaces, in precedence order (highest first):

1. **CLI flags** — `--runtime`, `--image`, `--timeout`, `--no-tty`, etc.
2. **Environment variables** — `RUN_RUNTIME`, `RUN_IMAGE`, `RUN_TIMEOUT`, etc.
3. **`commands/run.conf`** — `runtime = podman`, `image = myproject:latest`, `timeout = 60`

### Command directory layout

```
commands/
├── run.conf          # project config (image, runtime, timeout, …)
├── env               # env vars injected for all commands
├── mount             # mounts applied for all commands
├── help.md           # top-level listing description
├── build/
│   ├── main.sh       # ./myproject build → runs this inside the container
│   ├── env           # additional env vars for build only
│   └── help.md       # ./myproject build --help
└── release/
    ├── package/
    │   ├── main.sh   # ./myproject release package → runs this
    │   └── conf      # dispatch = host — runs on the host, not the container
    └── help.md
```

`main.<ext>` probe order: `main` (no extension) → `main.py` → `main.nu` →
`main.sh` → `main.rb` → `main.js` → `main.pl`.

## Exit codes

| Code | Meaning                                    |
|------|--------------------------------------------|
| *    | Passes through the container command's exit code |
| 124  | Container exceeded `--timeout` limit       |
| 125  | run.sh configuration or runtime error      |

## Full reference

```sh
./myproject --help
```

## License

MIT — see [LICENSE](LICENSE).
