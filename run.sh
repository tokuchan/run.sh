#!/bin/sh
# run.sh — run containerized commands in your dev environment
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
# §07  ENVIRONMENT CONSTRUCTION
# §08  RUNTIME DETECTION & UID MAPPING
# §09  CONTAINER INVOCATION
# §10  MAIN
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# §01 HELP & USAGE
# ─────────────────────────────────────────────────────────────
# §01.01  usage()  — single-screen cheat sheet
# §01.02  help()   — full manual

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

Stem files (resolved from run root):
  default.run / default.env   always loaded first
  <stem>.run  / <stem>.env    loaded for matched stem
  fs/<stem>/                  host-side mount sources

Run 'run --help' for the full manual with all options and examples.
EOF
}

# §01.02 help
help() {
    cat <<'EOF'
NAME
    run — run containerized commands in your dev environment

DESCRIPTION
    run.sh wraps a container runtime (podman or docker) to execute commands
    inside a project-specific container while keeping host and container paths
    aligned. The current working directory, project root, and any configured
    mount sets are bind-mounted at the same absolute paths inside the container,
    so compiler output, debugger paths, and tool output are identical on host
    and inside the container.

SYNOPSIS
    run [OPTIONS] [STEM] [--] COMMAND [ARGS...]

    If run.sh is invoked via a symlink, the symlink name is the stem.
    Otherwise the first non-option argument is the stem.

STEM & CONFIGURATION FILES
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

OPTIONS
  Stem selection:
    -s, --stem <name>      Load an additional stem (repeatable)

  Mounts:
    --mirror <path>        Canonicalize path, bind-mount at same abs path (rw)
    --mirror-ro <path>     Same, read-only
    --cwd / --no-cwd       Mirror CWD and project root (default: on)

  Environment:
    --env-host / --no-env-host
                           Forward host environment into container (default: on)

  Container:
    --runtime <r>          podman or docker (default: auto-detect)
    --image <img>          Container image (overrides run.conf)
    --tty / --no-tty       Allocate pseudo-TTY (default: auto-detect)

  Diagnostics:
    --dry-run              Print resolved invocation to stderr; do not execute
    -v, --verbose          Increase verbosity (repeat for more: -vv, -vvv)
    -q, --quiet            Suppress non-error log output
    --project-root <path>  Override project root detection

  General:
    -h, --help             Show this manual

LOG FORMAT
    All run.sh diagnostics go to stderr:
      TIMESTAMP [SEVERITY] run: MESSAGE [JSON]

    Severity levels: [DEBUG] [INFO ] [WARN ] [ERROR]

    POSIX tool recipes:
      Filter errors:   run ... 2>&1 | grep '\[ERROR\]'
      Extract JSON:    run ... 2>&1 | grep -oE '\{[^}]*\}'
      Clean messages:  run ... 2>&1 | sed 's/ {[^}]*}$//'

EXIT CODES
    Passes through the container command's exit code.
    125  run.sh itself failed (bad config, missing runtime, etc.)

EXAMPLES
    run g++ -o hello hello.cpp
    run -s nix nix build .
    run --mirror ~/.config -- nvim src/main.c
    run --dry-run make all
    ln -s run.sh g++ && ./g++ -o hello hello.cpp
EOF
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

_KNOWN_KEYS="image runtime stems project_root verbose quiet dry_run cwd env_host tty"

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
# §09 CONTAINER INVOCATION
# ─────────────────────────────────────────────────────────────
# §09.01  dry_run_print()  — print resolved invocation

# §09.01 dry_run_print
dry_run_print() {
    # Dry-run always prints — user explicitly asked for it, so bypass verbosity gate
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s [INFO ] run: dry-run image=%s command: %s\n' \
        "$ts" "${RUN_IMAGE:-<unset>}" "$RUN_USER_CMD" >&2
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

    find_run_root || exit 125

    parse_conf "$RUN_RUN_ROOT/run.conf"
    apply_env

    if [ "${RUN_DRY_RUN:-0}" = "1" ]; then
        dry_run_print
        exit 0
    fi
}

main "$@"
