#!/bin/sh
# run.sh — run containerized commands in your dev environment
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Sean Spillane
#
# VIM NAVIGATION
# ─────────────────────────────────────────────────────────────
# Section markers use § (U+00A7). To search without typing §,
# add this to .vimrc — then /ss05 finds §05, /ss05.03 finds §05.03:
#   cnoreabbrev ss §
#
# Jump to section:           /§05<CR>   (or: /ss05<CR> with abbrev)
# Jump to subsection:        /§05\.03<CR>
# List all sections:         :g/^# §[0-9]/p
# List subsections of §05:   :g/^# §05\./p
# Jump to word under cursor: yiw/<C-R>0<CR>
#
# Suggested .vimrc mappings:
#   cnoreabbrev ss §
#   nnoremap <Leader>] yiw/<C-R>0<CR>
#   nnoremap <Leader>§ :vimgrep /^# §/ % \| copen<CR>
#
# ─────────────────────────────────────────────────────────────
# MASTER TABLE OF CONTENTS
# ─────────────────────────────────────────────────────────────
# §01  HELP & USAGE
# §02  LOGGING
# §03  CONFIGURATION
# §04  RUN ROOT & PROJECT ROOT
# §05  STEM RESOLUTION
# §06  MOUNT CONSTRUCTION
# §07  IMAGE MANAGEMENT
# §08  RUNTIME DETECTION & UID MAPPING
# §09  CONTAINER INVOCATION
# §10  MAIN
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# §01 HELP & USAGE
# ─────────────────────────────────────────────────────────────
# §01.01  usage()   — single-screen cheat sheet
# §01.02  help()    — full manual
# §01.03  do_init() — write stub files to CWD and exit

# §01.01 usage
usage() {
    cat <<'EOF'
Usage: run [OPTIONS] [STEM] [--] COMMAND [ARGS...]
       run [OPTIONS] [--] COMMAND [ARGS...]   (stem from argv[0] if symlinked)

Run a containerized command with project mounts and environment.

Common options:
  -s, --stem <name>      Load additional stem (repeatable)
  --mirror <path>        Bind-mount path at same location inside container
  --mirror-ro <path>     Same, read-only
  --no-cwd               Do not mirror CWD and project root
  --no-env-host          Do not forward host environment
  --dry-run              Print resolved container invocation; do not run
  -v, --verbose          Increase log verbosity (repeatable: -vv)
  -q, --quiet            Suppress non-error output
  --runtime <r>          Container runtime: podman (default) or docker
  --help                 Show full manual

Image management (all default on; use --no-* to suppress):
  --build / --no-build        Auto-build image when absent
  --rebuild / --no-rebuild    Auto-rebuild when Dockerfile fingerprint changes
  --force-rebuild             Rebuild unconditionally
  --clean                     Remove image and exit
  --store <mode>              Nix store: shared (default) or local

Bootstrap:
  --init                 Write Dockerfile, flake.nix, and run.conf to CWD
  --init-container       Write Dockerfile only
  --init-flake           Write flake.nix only
  --init-config          Write run.conf only

Stem files (resolved from run root):
  default.run / default.env   always loaded first
  <stem>.run  / <stem>.env    loaded for matched stem
  fs/<stem>/                  host-side mount sources

Run 'run --help' for the full manual with all options and examples.
EOF
}

# §01.02a _help_body — help text with SGR semantic variables (set by help())
_help_body() {
    cat <<EOF
${SECTION}NAME${RESET}
    run — run containerized commands in your dev environment

${SECTION}DESCRIPTION${RESET}
    run.sh wraps a container runtime (podman or docker) to execute commands
    inside a project-specific container while keeping host and container paths
    aligned. The current working directory, project root, and any configured
    mount sets are bind-mounted at the same absolute paths inside the container,
    so compiler output, debugger paths, and tool output are identical on host
    and inside the container.

${SECTION}SYNOPSIS${RESET}
    run [OPTIONS] [STEM] [--] COMMAND [ARGS...]

    If run.sh is invoked via a symlink, the symlink name is the stem.
    Otherwise the first non-option argument is the stem.

${SECTION}STEM & CONFIGURATION FILES${RESET}
    Stems select sets of mounts and environment variables. Resolution order:
      1. default.run + default.env  (always loaded first)
      2. <stem>.run + <stem>.env    (auto-resolved stem)
      3. stems listed in run.conf   (project baseline)
      4. --stem / -s options        (explicit, left-to-right)

    .run file format:
      /absolute/container/path   bind-mount fs/<stem>/absolute/path here
      @include <name>            load <name>.run and <name>.env
      # comment                  ignored

    .env file format:
      KEY=VALUE                  inject into container environment
      # comment                  ignored

${SECTION}OPTIONS${RESET}
  ${SUBSECTION}Stem selection:${RESET}
    -s, --stem <name>      Load an additional stem (repeatable)

  ${SUBSECTION}Mounts:${RESET}
    --mirror <path>        Canonicalize path, bind-mount at same abs path (rw)
    --mirror-ro <path>     Same, read-only
    --cwd / --no-cwd       Mirror CWD and project root (default: on)

  ${SUBSECTION}Environment:${RESET}
    --env-host / --no-env-host
                           Forward host environment into container (default: on)

  ${SUBSECTION}Container:${RESET}
    --runtime <r>          podman or docker (default: auto-detect)
    --image <img>          Container image (overrides run.conf)
    --tty / --no-tty       Allocate pseudo-TTY (default: auto-detect)

  ${SUBSECTION}Image management:${RESET}
    --build / --no-build        Auto-build image when absent (default: on)
    --rebuild / --no-rebuild    Auto-rebuild when Dockerfile fingerprint
                                changes (default: on)
    --force-rebuild             Rebuild unconditionally regardless of fingerprint
    --clean                     Remove image and exit 0

  ${SUBSECTION}Nix store:${RESET}
    --store <mode>         Mount mode for /nix inside container:
                             shared  XDG_CACHE_HOME/run/nix (default)
                             local   <run-root>/fs/default/nix
                           Store is seeded from image on first use.

  ${SUBSECTION}Diagnostics:${RESET}
    --dry-run              Print resolved invocation to stderr; do not execute
    -v, --verbose          Increase verbosity (repeat for more: -vv, -vvv)
    -q, --quiet            Suppress non-error log output
    --project-root <path>  Override project root detection

  ${SUBSECTION}Bootstrap${RESET} (writes stub files to CWD; never clobbers existing files):
    --init                 Write Dockerfile, flake.nix, and run.conf
    --init-container       Write Dockerfile (and append .gitignore entries)
    --init-flake           Write flake.nix with devShells.default
    --init-config          Write run.conf with image placeholder

  ${SUBSECTION}General:${RESET}
    -h, --help             Show this manual

${SECTION}LOG FORMAT${RESET}
    All run.sh diagnostics go to stderr:
      TIMESTAMP [SEVERITY] run: MESSAGE [JSON]

    Severity levels: [DEBUG] [INFO ] [WARN ] [ERROR]

    POSIX tool recipes:
      Filter errors:   run ... 2>&1 | grep '\[ERROR\]'
      Extract JSON:    run ... 2>&1 | grep -oE '\{[^}]*\}'
      Clean messages:  run ... 2>&1 | sed 's/ {[^}]*}$//'

${SECTION}EXIT CODES${RESET}
    Passes through the container command's exit code.
    125  run.sh itself failed (bad config, missing runtime, etc.)

${SECTION}EXAMPLES${RESET}
    # Bootstrap a new project
    run --init                         # write Dockerfile, flake.nix, run.conf
    \$EDITOR flake.nix                  # add your packages to devShells.default
    run make all                       # image built automatically on first run

    # Daily use
    run g++ -o hello hello.cpp
    run -s nix nix build .
    run --mirror ~/.config -- nvim src/main.c
    run --dry-run make all
    ln -s run.sh g++ && ./g++ -o hello hello.cpp

    # Image management
    run --force-rebuild make all       # rebuild image then run
    run --clean                        # remove image
EOF
}

# §01.02 help
help() {
    # SGR primitives — empty when NO_COLOR is set or stdout is not a terminal
    local BOLD="" CYAN="" RESET=""
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
        BOLD="$(printf '\033[1m')"
        CYAN="$(printf '\033[36m')"
        RESET="$(printf '\033[0m')"
    fi
    # Semantic variables built from primitives
    local SECTION="${BOLD}${CYAN}"
    local SUBSECTION="${BOLD}"

    # Pager detection: $PAGER → less -FRX → more (non-TTY: no pager)
    local pager=""
    if [ -t 1 ]; then
        if [ -n "${PAGER:-}" ]; then
            pager="$PAGER"
        elif command -v less >/dev/null 2>&1; then
            pager="less -FRX"
        elif command -v more >/dev/null 2>&1; then
            pager="more"
        fi
    fi
    if [ -n "$pager" ]; then
        _help_body | $pager
    else
        _help_body
    fi
}

# §01.03 do_init
# Write stub files to CWD based on RUN_INIT_* flags. Never clobbers.
# Smart-appends .gitignore. Exits 0 when done.
do_init() {
    local wrote=0

    if [ "${RUN_INIT_CONTAINER:-0}" = "1" ]; then
        if [ -f "Dockerfile" ]; then
            log_warn "Dockerfile already exists, skipping"
        else
            cat > "Dockerfile" <<'DOCKERFILE'
FROM nixos/nix:latest

# Enable flakes; disable sandbox (required inside containers).
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf \
    && echo "sandbox = false" >> /etc/nix/nix.conf

# DO NOT add packages here. Declare all project tools in flake.nix instead.
# The nix store is mounted from the host — packages install on first run
# and are cached across invocations. See docs/adr/0008 and docs/adr/0011.

WORKDIR /workspace
CMD ["/bin/bash"]
DOCKERFILE
            log_info "wrote Dockerfile"
            wrote=1
        fi

        # Smart-append .gitignore entries
        for _entry in "fs/default/nix/" "result"; do
            if [ -f ".gitignore" ] && grep -qF "$_entry" ".gitignore"; then
                :
            else
                printf '%s\n' "$_entry" >> ".gitignore"
            fi
        done
    fi

    if [ "${RUN_INIT_FLAKE:-0}" = "1" ]; then
        if [ -f "flake.nix" ]; then
            log_warn "flake.nix already exists, skipping"
        else
            cat > "flake.nix" <<'FLAKE'
{
  description = "run.sh dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # Change x86_64-linux to aarch64-linux for ARM hosts.
      system = "x86_64-linux";
      pkgs   = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          bash
          coreutils
          git
          # run:packages — managed by 'run --add / --remove'; do not delete this line
        ];
      };
    };
}
FLAKE
            log_info "wrote flake.nix"
            wrote=1
        fi
    fi

    if [ "${RUN_INIT_CONFIG:-0}" = "1" ]; then
        if [ -f "run.conf" ]; then
            log_warn "run.conf already exists, skipping"
        else
            cat > "run.conf" <<'RUNCONF'
# run.conf — project configuration for run.sh
# Precedence: CLI option > RUN_* env var > this file > built-in default.

image   = run-toolchain:latest
runtime = podman
# store = shared   # shared (default) or local (hermetic, per-project)
RUNCONF
            log_info "wrote run.conf"
            wrote=1
        fi
    fi

    [ "$wrote" = "0" ] && log_info "nothing to write"
    exit 0
}

# ─────────────────────────────────────────────────────────────
# §02 LOGGING
# ─────────────────────────────────────────────────────────────
# §02.01  log_debug()  — verbosity level 3
# §02.02  log_info()   — verbosity level 2
# §02.03  log_warn()   — verbosity level 1 (default on)
# §02.04  log_error()  — always shown

_log() {
    local level="$1" min_verbosity="$2" msg="$3" json="${4:-}"
    [ "${RUN_VERBOSITY:-1}" -ge "$min_verbosity" ] || return 0
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -n "$json" ]; then
        printf '%s [%s] run: %s %s\n' "$ts" "$level" "$msg" "$json" >&2
    else
        printf '%s [%s] run: %s\n' "$ts" "$level" "$msg" >&2
    fi
}

# §02.01 log_debug
log_debug() { _log "DEBUG" 3 "$@"; }
# §02.02 log_info
log_info()  { _log "INFO " 2 "$@"; }
# §02.03 log_warn
log_warn()  { _log "WARN " 1 "$@"; }
# §02.04 log_error
log_error() { _log "ERROR" 0 "$@"; }

# ─────────────────────────────────────────────────────────────
# §03 CONFIGURATION
# ─────────────────────────────────────────────────────────────
# §03.01  defaults        — built-in default values
# §03.02  parse_conf()    — read run.conf key=value
# §03.03  apply_env()     — apply RUN_* env overrides
# §03.04  parse_args()    — command-line option parsing

_KNOWN_KEYS="image runtime stems project_root verbose quiet dry_run cwd env_host tty build rebuild force_rebuild store timeout"

# §03.01 defaults
defaults() {
    RUN_IMAGE="${RUN_IMAGE:-}"
    RUN_RUNTIME="${RUN_RUNTIME:-}"
    RUN_STEMS="${RUN_STEMS:-}"
    RUN_PROJECT_ROOT="${RUN_PROJECT_ROOT:-}"
    RUN_VERBOSITY="${RUN_VERBOSITY:-1}"
    RUN_DRY_RUN="${RUN_DRY_RUN:-0}"
    RUN_CWD="${RUN_CWD:-1}"
    RUN_ENV_HOST="${RUN_ENV_HOST:-1}"
    RUN_TTY="${RUN_TTY:-auto}"
    RUN_BUILD="${RUN_BUILD:-1}"
    RUN_REBUILD="${RUN_REBUILD:-1}"
    RUN_FORCE_REBUILD="${RUN_FORCE_REBUILD:-0}"
    RUN_CLEAN="${RUN_CLEAN:-0}"
    RUN_STORE="${RUN_STORE:-shared}"
    RUN_INIT_CONTAINER="${RUN_INIT_CONTAINER:-0}"
    RUN_INIT_FLAKE="${RUN_INIT_FLAKE:-0}"
    RUN_INIT_CONFIG="${RUN_INIT_CONFIG:-0}"
    RUN_PKG_SEARCH="${RUN_PKG_SEARCH:-}"
    RUN_PKG_ADD="${RUN_PKG_ADD:-}"
    RUN_PKG_REMOVE="${RUN_PKG_REMOVE:-}"
    RUN_TIMEOUT="${RUN_TIMEOUT:-0}"
}

# §03.02 parse_conf
parse_conf() {
    local conf_file="$1"
    [ -f "$conf_file" ] || return 0
    local line key value
    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "$key" | tr -d ' ')"
        value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
        if ! printf '%s' " $_KNOWN_KEYS " | grep -qF " $key "; then
            log_error "unknown key '$key' in $conf_file"
            exit 125
        fi
        case "$key" in
            image)        RUN_IMAGE="$value" ;;
            runtime)      RUN_RUNTIME="$value" ;;
            stems)        RUN_STEMS="$value" ;;
            project_root) RUN_PROJECT_ROOT="$value" ;;
            verbose)      RUN_VERBOSITY="$value" ;;
            quiet)        [ "$value" = "1" ] && RUN_VERBOSITY=0 ;;
            dry_run)      RUN_DRY_RUN="$value" ;;
            cwd)          RUN_CWD="$value" ;;
            env_host)     RUN_ENV_HOST="$value" ;;
            tty)          RUN_TTY="$value" ;;
            build)        RUN_BUILD="$value" ;;
            rebuild)      RUN_REBUILD="$value" ;;
            force_rebuild) RUN_FORCE_REBUILD="$value" ;;
            store)        RUN_STORE="$value" ;;
            timeout)      [ -z "${_CLI_TIMEOUT_SET:-}" ] && RUN_TIMEOUT="$value" ;;
        esac
    done < "$conf_file"
}

# §03.03 apply_env
apply_env() {
    [ -n "${RUN_IMAGE+x}"        ] && : # already set from env
    [ -n "${RUN_RUNTIME+x}"      ] && :
    [ -n "${RUN_DRY_RUN+x}"      ] && :
    [ -n "${RUN_NO_ENV_HOST+x}"  ] && RUN_ENV_HOST=0
    [ -n "${RUN_NO_CWD+x}"       ] && RUN_CWD=0
}

# §03.04 parse_args — sets RUN_USER_CMD and RUN_EXPLICIT_STEMS; removes run.sh flags from "$@"
parse_args() {
    RUN_EXPLICIT_STEMS=""
    RUN_MIRRORS=""
    RUN_MIRRORS_RO=""
    RUN_USER_CMD=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --)            shift; RUN_USER_CMD="$*"; break ;;
            --dry-run)     RUN_DRY_RUN=1; shift ;;
            --no-dry-run)  RUN_DRY_RUN=0; shift ;;
            --cwd)         RUN_CWD=1; shift ;;
            --no-cwd)      RUN_CWD=0; shift ;;
            --env-host)    RUN_ENV_HOST=1; shift ;;
            --no-env-host) RUN_ENV_HOST=0; shift ;;
            --tty)         RUN_TTY=1; shift ;;
            --no-tty)      RUN_TTY=0; shift ;;
            --runtime)     RUN_RUNTIME="$2"; shift 2 ;;
            --image)       RUN_IMAGE="$2"; shift 2 ;;
            --project-root) RUN_PROJECT_ROOT="$2"; shift 2 ;;
            -s|--stem)     RUN_EXPLICIT_STEMS="$RUN_EXPLICIT_STEMS $2"; shift 2 ;;
            --mirror)      RUN_MIRRORS="$RUN_MIRRORS $(readlink -f "$2")"; shift 2 ;;
            --mirror-ro)   RUN_MIRRORS_RO="$RUN_MIRRORS_RO $(readlink -f "$2")"; shift 2 ;;
            -v|--verbose)  RUN_VERBOSITY=$(( RUN_VERBOSITY + 1 )); shift ;;
            -q|--quiet)    RUN_VERBOSITY=0; shift ;;
            --build)       RUN_BUILD=1; shift ;;
            --no-build)    RUN_BUILD=0; shift ;;
            --rebuild)     RUN_REBUILD=1; shift ;;
            --no-rebuild)  RUN_REBUILD=0; shift ;;
            --force-rebuild) RUN_FORCE_REBUILD=1; shift ;;
            --clean)       RUN_CLEAN=1; shift ;;
            --store)       RUN_STORE="$2"; shift 2 ;;
            --init)        RUN_INIT_CONTAINER=1; RUN_INIT_FLAKE=1; RUN_INIT_CONFIG=1; shift ;;
            --init-container) RUN_INIT_CONTAINER=1; shift ;;
            --init-flake)  RUN_INIT_FLAKE=1; shift ;;
            --init-config) RUN_INIT_CONFIG=1; shift ;;
            --timeout)     RUN_TIMEOUT="$2"; _CLI_TIMEOUT_SET=1; shift 2 ;;
            --search)      RUN_PKG_SEARCH="$2"; shift 2 ;;
            --add)         RUN_PKG_ADD="$RUN_PKG_ADD $2"; shift 2 ;;
            --remove)      RUN_PKG_REMOVE="$RUN_PKG_REMOVE $2"; shift 2 ;;
            --help|-h)     help; exit 0 ;;
            -*)            log_error "unknown option: $1"; exit 125 ;;
            *)             RUN_USER_CMD="$*"; break ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────
# §04 RUN ROOT & PROJECT ROOT
# ─────────────────────────────────────────────────────────────
# §04.01  find_run_root()  — locate directory containing run.conf

# §04.01 find_run_root
# Sets RUN_RUN_ROOT global; returns 1 on failure (never calls exit — caller must handle).
find_run_root() {
    if [ -n "$RUN_PROJECT_ROOT" ]; then
        RUN_RUN_ROOT="$RUN_PROJECT_ROOT"
        return 0
    fi

    local root
    root="$(jj root 2>/dev/null)" && RUN_RUN_ROOT="$root" && return 0
    root="$(git rev-parse --show-toplevel 2>/dev/null)" && RUN_RUN_ROOT="$root" && return 0
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        [ -f "$dir/run.conf" ] && RUN_RUN_ROOT="$dir" && return 0
        dir="$(dirname "$dir")"
    done
    log_error "cannot find run root (no jj/git root and no run.conf in any ancestor directory)"
    return 1
}

# ─────────────────────────────────────────────────────────────
# §05 STEM RESOLUTION
# ─────────────────────────────────────────────────────────────
# §05.01  parse_env_file()  — parse KEY=VALUE env file into RUN_ENV_PAIRS

# ─────────────────────────────────────────────────────────────
# §05 STEM RESOLUTION
# ─────────────────────────────────────────────────────────────
# §05.01  resolve_stem()    — symlink dispatch → first positional word
# §05.02  parse_env_file()  — parse KEY=VALUE env file into RUN_ENV_PAIRS
# §05.03  parse_run_file()  — parse mount paths and @include directives
# §05.04  load_explicit_stems() — load stems from -s options

# §05.01 resolve_stem
# Sets RUN_STEM. If basename($0) != run.sh, uses that; otherwise uses
# the first word of RUN_USER_CMD (which remains unchanged — the stem
# name is also the first word of the command passed to the container).
resolve_stem() {
    local script_name
    script_name="$(basename "$0")"
    if [ "$script_name" != "run.sh" ]; then
        RUN_STEM="$script_name"
    else
        RUN_STEM="${RUN_USER_CMD%% *}"
    fi
}

# §05.04 load_explicit_stems
# Loads each stem listed in RUN_EXPLICIT_STEMS (space-separated).
load_explicit_stems() {
    local stem
    for stem in $RUN_EXPLICIT_STEMS; do
        parse_run_file "$stem" "$RUN_RUN_ROOT/${stem}.run"
        parse_env_file "$RUN_RUN_ROOT/${stem}.env"
    done
}

# §05.01 parse_env_file FILE
# Appends parsed KEY=VALUE pairs to RUN_ENV_PAIRS (newline-separated).
parse_env_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    local line
    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        RUN_ENV_PAIRS="${RUN_ENV_PAIRS}${line}
"
    done < "$file"
}

# §05.02 parse_run_file STEM FILE
# Appends bind-mount specs to RUN_MOUNT_PAIRS (host:container per line).
# Recursively processes @include directives (stem name, not file path).
# Guards against infinite include loops via RUN_INCLUDE_SEEN.
parse_run_file() {
    local stem="$1" file="$2"
    [ -f "$file" ] || return 0

    local seen_key="<<<${stem}>>>"
    case "$RUN_INCLUDE_SEEN" in
        *"$seen_key"*) log_warn "@include loop detected for stem '$stem', skipping"; return 0 ;;
    esac
    RUN_INCLUDE_SEEN="${RUN_INCLUDE_SEEN}${seen_key}"

    local line
    while IFS= read -r line; do
        case "$line" in
            ''|'#'*) continue ;;
            '@include '*)
                local inc_stem="${line#@include }"
                inc_stem="$(printf '%s' "$inc_stem" | tr -d ' ')"
                parse_run_file "$inc_stem" "$RUN_RUN_ROOT/${inc_stem}.run"
                parse_env_file "$RUN_RUN_ROOT/${inc_stem}.env"
                ;;
            /*)
                local host_path="${RUN_RUN_ROOT}/fs/${stem}${line}"
                RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${host_path}:${line}
"
                ;;
            *)
                log_warn "ignoring unrecognized line in ${file}: $line"
                ;;
        esac
    done < "$file"
}

# ─────────────────────────────────────────────────────────────
# §06 MOUNT CONSTRUCTION
# ─────────────────────────────────────────────────────────────
# §06.01  build_cwd_mounts()    — add CWD and project root mounts
# §06.02  build_mirror_mounts() — add --mirror / --mirror-ro mounts

# §06.01 build_cwd_mounts
# Appends CWD and project root bind-mounts to RUN_MOUNT_PAIRS.
# If CWD == project root, only one entry is added.
build_cwd_mounts() {
    [ "${RUN_CWD:-1}" = "1" ] || return 0
    local cwd project_root
    cwd="$(readlink -f "$PWD")"
    project_root="$(readlink -f "$RUN_RUN_ROOT")"

    RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${cwd}:${cwd}
"
    if [ "$project_root" != "$cwd" ]; then
        RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${project_root}:${project_root}
"
    fi
    RUN_WORKDIR="$cwd"
}

# §06.02 build_mirror_mounts
# Appends --mirror and --mirror-ro paths to RUN_MOUNT_PAIRS.
build_mirror_mounts() {
    local path
    for path in $RUN_MIRRORS; do
        RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${path}:${path}
"
    done
    for path in $RUN_MIRRORS_RO; do
        RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${path}:${path}:ro
"
    done
}

# ─────────────────────────────────────────────────────────────
# §07 IMAGE MANAGEMENT
# ─────────────────────────────────────────────────────────────
# §07.01  image_fingerprint()  — SHA256 of Dockerfile for staleness check
# §07.02  manage_image()       — clean / auto-build / auto-rebuild
# §07.03  mount_nix_store()    — add /nix special-purpose mount (shared or local)

# §07.01 image_fingerprint
# Prints SHA256 hash of Dockerfile at run root (used for staleness label).
image_fingerprint() {
    local df="$RUN_RUN_ROOT/Dockerfile"
    [ -f "$df" ] || { printf ''; return; }
    sha256sum "$df" | cut -d' ' -f1
}

# §07.02 manage_image
# Handles --clean, auto-build (image absent), auto-rebuild (image stale).
# Runs after detect_runtime; before stem resolution and invoke_container.
manage_image() {
    local image="${RUN_IMAGE:-}"
    [ -z "$image" ] && return 0

    # --clean: rmi and exit
    if [ "${RUN_CLEAN:-0}" = "1" ]; then
        if "$RUN_RUNTIME" image inspect "$image" >/dev/null 2>&1; then
            "$RUN_RUNTIME" rmi "$image"
        else
            log_warn "image $image not found, nothing to remove"
        fi
        exit 0
    fi

    # Dry-run: report what would happen, don't touch anything (ADR-0009)
    if [ "${RUN_DRY_RUN:-0}" = "1" ]; then
        return 0
    fi

    local image_present=0
    "$RUN_RUNTIME" image inspect "$image" >/dev/null 2>&1 && image_present=1

    # Auto-build: image absent
    if [ "$image_present" = "0" ]; then
        if [ "${RUN_BUILD:-1}" = "0" ]; then
            log_error "image $image not found and --no-build is set"
            exit 125
        fi
        _build_image
        return
    fi

    # Auto-rebuild: image stale (force-rebuild bypasses fingerprint check)
    if [ "${RUN_FORCE_REBUILD:-0}" = "1" ]; then
        _build_image
        return
    fi

    if [ "${RUN_REBUILD:-1}" = "1" ]; then
        local current_fp stored_fp
        current_fp="$(image_fingerprint)"
        stored_fp="$("$RUN_RUNTIME" image inspect \
            --format '{{index .Labels "run.fingerprint"}}' "$image" 2>/dev/null)"
        if [ -n "$current_fp" ] && [ "$current_fp" != "$stored_fp" ]; then
            log_info "image $image is stale (Dockerfile changed), rebuilding"
            _build_image
        fi
    fi
}

# Build image, tagging with current Dockerfile fingerprint.
_build_image() {
    local fp
    fp="$(image_fingerprint)"
    log_info "building image $RUN_IMAGE"
    if [ "${RUN_VERBOSITY:-1}" -ge 2 ]; then
        "$RUN_RUNTIME" build \
            --label "run.fingerprint=${fp}" \
            -t "$RUN_IMAGE" "$RUN_RUN_ROOT"
    else
        "$RUN_RUNTIME" build \
            --label "run.fingerprint=${fp}" \
            -t "$RUN_IMAGE" "$RUN_RUN_ROOT" >/dev/null 2>&1
    fi
}

# §07.03 mount_nix_store
# Adds /nix special-purpose mount to RUN_MOUNT_PAIRS.
# shared mode: $XDG_CACHE_HOME/run/nix (default ~/.cache/run/nix)
# local mode:  <run-root>/fs/default/nix
# On first use (store empty), seeds the store from the image so packages
# already installed in the image remain available after the mount.
# Seeding is skipped in dry-run (ADR-0009: dry-run never changes state).
mount_nix_store() {
    local store_root
    case "${RUN_STORE:-shared}" in
        local)
            store_root="${RUN_RUN_ROOT}/fs/default/nix"
            ;;
        *)
            local cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
            store_root="${cache_home}/run/nix"
            ;;
    esac
    mkdir -p "$store_root"
    if [ -z "$(ls -A "$store_root" 2>/dev/null)" ]; then
        if [ -n "${RUN_IMAGE:-}" ] && [ "${RUN_DRY_RUN:-0}" != "1" ]; then
            if "$RUN_RUNTIME" image inspect "$RUN_IMAGE" >/dev/null 2>&1; then
                log_info "seeding nix store from $RUN_IMAGE (first use)"
                "$RUN_RUNTIME" run --rm \
                    --volume "${store_root}:/nix-host" \
                    "$RUN_IMAGE" \
                    sh -c 'cp -a /nix/. /nix-host/'
            fi
        fi
    fi
    [ "$(ls -A "$store_root" 2>/dev/null)" ] || return 0
    RUN_MOUNT_PAIRS="${RUN_MOUNT_PAIRS}${store_root}:/nix
"
}

# ─────────────────────────────────────────────────────────────
# §08 RUNTIME DETECTION & UID MAPPING
# ─────────────────────────────────────────────────────────────
# §08.01  detect_runtime()  — podman → docker auto-detect
# §08.02  uid_map_args()    — runtime-specific UID/GID mapping flags

# §08.01 detect_runtime
detect_runtime() {
    if [ -n "$RUN_RUNTIME" ]; then
        return 0
    fi
    if command -v podman >/dev/null 2>&1; then
        RUN_RUNTIME="podman"
    elif command -v docker >/dev/null 2>&1; then
        RUN_RUNTIME="docker"
    else
        log_error "no container runtime found (tried podman, docker)"
        return 1
    fi
}

# §08.02 uid_map_args — prints runtime-specific UID mapping flags to stdout
uid_map_args() {
    case "$RUN_RUNTIME" in
        podman) printf '%s' "--userns=keep-id" ;;
        docker) printf '%s' "--user $(id -u):$(id -g)" ;;
    esac
}

# ─────────────────────────────────────────────────────────────
# §09 CONTAINER INVOCATION
# ─────────────────────────────────────────────────────────────
# §09.01  dry_run_print()   — print resolved invocation
# §09.02  invoke_container() — build and exec the container command

# §09.01 dry_run_print
dry_run_print() {
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local pair
    printf '%s\n' "$RUN_MOUNT_PAIRS" | while IFS= read -r pair; do
        [ -z "$pair" ] && continue
        printf '%s [INFO ] run: dry-run mount %s\n' "$ts" "$pair" >&2
    done
    printf '%s\n' "$RUN_ENV_PAIRS" | while IFS= read -r pair; do
        [ -z "$pair" ] && continue
        printf '%s [INFO ] run: dry-run env %s\n' "$ts" "$pair" >&2
    done
    if [ "${RUN_DEVSHELL:-0}" = "1" ]; then
        printf '%s [INFO ] run: dry-run nix develop path:%s --command %s\n' \
            "$ts" "$RUN_RUN_ROOT" "$RUN_USER_CMD" >&2
    else
        printf '%s [INFO ] run: dry-run image=%s command: %s\n' \
            "$ts" "${RUN_IMAGE:-<unset>}" "$RUN_USER_CMD" >&2
    fi
    if [ "${RUN_TIMEOUT:-0}" != "0" ]; then
        printf '%s [INFO ] run: dry-run timeout=%ss\n' "$ts" "$RUN_TIMEOUT" >&2
    fi
}

# §09.02a _invoke_with_timeout — run container in background with a timer
# Called by invoke_container when RUN_TIMEOUT > 0. Runs container in background
# (no TTY), starts a sleep timer in a subshell. Timer fires -> kill container
# process + touch sentinel. Parent waits for container; sentinel presence
# distinguishes timeout from normal exit. Exits 124 on timeout.
_invoke_with_timeout() {
    local _cname="run-$$"
    local _sentinel="/tmp/run-timeout-$$"
    rm -f "$_sentinel"

    # Run container in background without TTY; args already built by invoke_container
    if [ "${RUN_DEVSHELL:-0}" = "1" ]; then
        "$RUN_RUNTIME" run --name "$_cname" "$@" "$RUN_IMAGE" \
            nix develop "path:$RUN_RUN_ROOT" --command $RUN_USER_CMD &
    else
        "$RUN_RUNTIME" run --name "$_cname" --entrypoint bash "$@" "$RUN_IMAGE" \
            -c '"$@"' -- $RUN_USER_CMD &
    fi
    local _cpid=$!

    # Background timer: write sentinel FIRST so parent sees it after wait returns,
    # then kill the docker run process and stop the container gracefully.
    ( sleep "$RUN_TIMEOUT" && touch "$_sentinel" && \
      kill "$_cpid" 2>/dev/null && \
      "$RUN_RUNTIME" stop "$_cname" 2>/dev/null ) &
    local _tpid=$!

    wait "$_cpid"
    local _exit=$?

    kill "$_tpid" 2>/dev/null
    wait "$_tpid" 2>/dev/null

    if [ -f "$_sentinel" ]; then
        rm -f "$_sentinel"
        log_error "command timed out after ${RUN_TIMEOUT}s"
        exit 124
    fi
    return "$_exit"
}

# §09.02 invoke_container
# Build and exec the container command. Uses here-doc redirections (not pipes)
# to iterate over mount/env pairs while staying in the current shell so that
# set -- accumulates args without subshell isolation.
invoke_container() {
    # Start building positional params for: $runtime run <args> $image -c '"$@"' -- $cmd
    set --

    # UID mapping
    case "$RUN_RUNTIME" in
        podman) set -- "$@" --userns=keep-id ;;
        docker) set -- "$@" --user "$(id -u):$(id -g)" ;;
    esac

    # Stdin always connected; TTY auto-detected
    set -- "$@" -i
    local do_tty="$RUN_TTY"
    [ "$do_tty" = "auto" ] && { [ -t 0 ] && do_tty=1 || do_tty=0; }
    [ "$do_tty" = "1" ] && set -- "$@" -t

    # Mounts — here-doc keeps loop in current shell (no subshell, set -- works)
    while IFS= read -r _pair; do
        [ -z "$_pair" ] && continue
        set -- "$@" --volume "$_pair"
    done <<_MOUNTS_
$RUN_MOUNT_PAIRS
_MOUNTS_

    # Env host forwarding (podman only; docker: individual --env flags)
    if [ "${RUN_ENV_HOST:-1}" = "1" ]; then
        [ "$RUN_RUNTIME" = "podman" ] && set -- "$@" --env-host
    fi

    # Env pairs from .env files
    while IFS= read -r _pair; do
        [ -z "$_pair" ] && continue
        set -- "$@" --env "$_pair"
    done <<_ENVS_
$RUN_ENV_PAIRS
_ENVS_

    # Workdir
    [ -n "${RUN_WORKDIR:-}" ] && set -- "$@" --workdir "$RUN_WORKDIR"

    # Execute and propagate exit code
    if [ "${RUN_TIMEOUT:-0}" != "0" ]; then
        _invoke_with_timeout "$@"
    elif [ "${RUN_DEVSHELL:-0}" = "1" ]; then
        # devShell mode: nix develop resolves all packages then forwards the command
        "$RUN_RUNTIME" run "$@" "$RUN_IMAGE" \
            nix develop "path:$RUN_RUN_ROOT" --command $RUN_USER_CMD
    else
        # Direct mode: bash entrypoint with POSIX-safe arg forwarding
        set -- "$@" --entrypoint bash
        "$RUN_RUNTIME" run "$@" "$RUN_IMAGE" -c '"$@"' -- $RUN_USER_CMD
    fi
}

# ─────────────────────────────────────────────────────────────
# §13 PACKAGE MANAGEMENT
# ─────────────────────────────────────────────────────────────
# §13.01  pkg_search()  — run nix search nixpkgs inside container
# §13.02  pkg_add()     — validate + insert package above sentinel
# §13.03  pkg_remove()  — delete package line from flake.nix

# §13.01 pkg_search
pkg_search() {
    local term="$1"
    "$RUN_RUNTIME" run --rm "$RUN_IMAGE" nix search nixpkgs "$term"
}

# §13.02 pkg_add
pkg_add() {
    local pkg="$1"
    local flake="${RUN_RUN_ROOT}/flake.nix"

    if [ ! -f "$flake" ]; then
        log_error "flake.nix not found at $flake; cannot add package"
        exit 125
    fi

    local sentinel="# run:packages"
    if ! grep -qF "$sentinel" "$flake"; then
        log_error "sentinel '$sentinel' not found in flake.nix; add packages manually"
        exit 125
    fi

    if grep -qE "^[[:space:]]+${pkg}[[:space:]]*$" "$flake"; then
        log_warn "package '$pkg' already in flake.nix; nothing to do"
        return 0
    fi

    if ! "$RUN_RUNTIME" run --rm "$RUN_IMAGE" nix eval "nixpkgs#${pkg}" >/dev/null 2>&1; then
        log_error "package '$pkg' not found in nixpkgs (nix eval nixpkgs#${pkg} failed)"
        exit 125
    fi

    sed -i "s|${sentinel}|        ${pkg}\n        ${sentinel}|" "$flake"
    log_warn "added '$pkg' to flake.nix — run 'run true' to pre-warm the nix store"
}

# §13.03 pkg_remove
pkg_remove() {
    local pkg="$1"
    local flake="${RUN_RUN_ROOT}/flake.nix"

    if [ ! -f "$flake" ]; then
        log_error "flake.nix not found at $flake; cannot remove package"
        exit 125
    fi

    if ! grep -qE "^[[:space:]]+${pkg}[[:space:]]*$" "$flake"; then
        log_warn "package '$pkg' not found in flake.nix; nothing to do"
        return 0
    fi

    sed -i "/^[[:space:]]*${pkg}[[:space:]]*$/d" "$flake"
    log_warn "removed '$pkg' from flake.nix"
}

# §13.04 manage_packages
# Runs --search, then --add, then --remove. Called from main after manage_image.
manage_packages() {
    local did_something=0

    if [ -n "${RUN_PKG_SEARCH:-}" ]; then
        pkg_search "$RUN_PKG_SEARCH"
        did_something=1
    fi

    for pkg in ${RUN_PKG_ADD:-}; do
        pkg_add "$pkg"
        did_something=1
    done

    for pkg in ${RUN_PKG_REMOVE:-}; do
        pkg_remove "$pkg"
        did_something=1
    done

    [ "$did_something" = "1" ] && exit 0
}

# ─────────────────────────────────────────────────────────────
# §10 MAIN
# ─────────────────────────────────────────────────────────────

# §10.01 main
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi

    case "$1" in
        --help|-h)
            help
            exit 0
            ;;
    esac

    defaults
    parse_args "$@"

    # Init mode: write stub files and exit immediately (no run root needed).
    if [ "${RUN_INIT_CONTAINER:-0}" = "1" ] || \
       [ "${RUN_INIT_FLAKE:-0}"     = "1" ] || \
       [ "${RUN_INIT_CONFIG:-0}"    = "1" ]; then
        do_init
    fi

    find_run_root || exit 125

    parse_conf "$RUN_RUN_ROOT/run.conf"
    apply_env

    resolve_stem

    RUN_ENV_PAIRS=""
    RUN_MOUNT_PAIRS=""
    RUN_INCLUDE_SEEN=""

    # Load order: default → resolved stem → run.conf stems → -s explicit stems
    parse_run_file "default" "$RUN_RUN_ROOT/default.run"
    parse_env_file "$RUN_RUN_ROOT/default.env"
    if [ -n "$RUN_STEM" ] && [ "$RUN_STEM" != "default" ]; then
        parse_run_file "$RUN_STEM" "$RUN_RUN_ROOT/${RUN_STEM}.run"
        parse_env_file "$RUN_RUN_ROOT/${RUN_STEM}.env"
    fi
    load_explicit_stems
    detect_runtime || exit 125
    manage_image
    manage_packages
    mount_nix_store

    build_cwd_mounts
    build_mirror_mounts

    RUN_DEVSHELL=0
    [ -f "${RUN_RUN_ROOT}/flake.nix" ] && RUN_DEVSHELL=1

    # Warn early (before dry-run exits) so the conflict is always visible
    if [ "${RUN_TIMEOUT:-0}" != "0" ] && [ "${RUN_TTY:-auto}" = "1" ]; then
        log_warn "--tty ignored: --timeout implies no TTY"
    fi

    if [ "${RUN_DRY_RUN:-0}" = "1" ]; then
        dry_run_print
        exit 0
    fi

    invoke_container
    exit $?
}

main "$@"
