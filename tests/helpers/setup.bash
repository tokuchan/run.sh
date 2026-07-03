#!/usr/bin/env bash
# Shared bats setup: temp fixture dir, fake runtime shim, fake VCS shims.

bats_require_minimum_version 1.5.0

RUN_SH="$BATS_TEST_DIRNAME/../run.sh"

setup_fixture() {
    FIXTURE_DIR="$(mktemp -d)"
    export FIXTURE_DIR
}

teardown_fixture() {
    rm -rf "$FIXTURE_DIR"
}

# Inject a fake container runtime into PATH that records its invocation.
# Sets FAKE_RUNTIME_LOG to the capture file.
#
# Control variables (export before setup or per-test):
#   FAKE_RUNTIME_EXIT       — exit code for 'run' subcommand (default: 0)
#   FAKE_RUNTIME_HANG       — seconds the 'run' subcommand sleeps before exiting (default: 0)
#   FAKE_IMAGE_EXISTS       — "1" means image inspect succeeds (default: 1)
#   FAKE_IMAGE_FINGERPRINT  — value returned for run.fingerprint label (default: "")
setup_fake_runtime() {
    local bin_dir="$FIXTURE_DIR/bin"
    mkdir -p "$bin_dir"
    FAKE_RUNTIME_LOG="$FIXTURE_DIR/runtime.log"
    FAKE_RUNTIME_EXIT="${FAKE_RUNTIME_EXIT:-0}"
    FAKE_RUNTIME_HANG="${FAKE_RUNTIME_HANG:-0}"
    FAKE_IMAGE_EXISTS="${FAKE_IMAGE_EXISTS:-1}"
    FAKE_IMAGE_FINGERPRINT="${FAKE_IMAGE_FINGERPRINT:-}"
    FAKE_NIX_EVAL_EXIT="${FAKE_NIX_EVAL_EXIT:-0}"
    FAKE_NIX_SEARCH_OUTPUT="${FAKE_NIX_SEARCH_OUTPUT:-nixpkgs#nodejs  20.0  Node.js}"
    export FAKE_RUNTIME_LOG FAKE_RUNTIME_EXIT FAKE_RUNTIME_HANG FAKE_IMAGE_EXISTS FAKE_IMAGE_FINGERPRINT
    export FAKE_NIX_EVAL_EXIT FAKE_NIX_SEARCH_OUTPUT

    cat > "$bin_dir/podman" <<'EOF'
#!/bin/sh
echo "$@" >> "$FAKE_RUNTIME_LOG"
case "$1" in
    image)
        case "$2" in
            inspect)
                if [ "$FAKE_IMAGE_EXISTS" = "1" ]; then
                    case "$*" in
                        *run.fingerprint*) printf '%s\n' "$FAKE_IMAGE_FINGERPRINT" ;;
                    esac
                    exit 0
                else
                    exit 1
                fi
                ;;
        esac
        ;;
    rmi)   exit 0 ;;
    build) exit 0 ;;
    stop)  exit 0 ;;
    run)
        case "$*" in
            *"nix search"*) printf '%s\n' "$FAKE_NIX_SEARCH_OUTPUT"; exit 0 ;;
            *"nix eval"*)   exit "$FAKE_NIX_EVAL_EXIT" ;;
            *)
                [ "${FAKE_RUNTIME_HANG:-0}" -gt 0 ] && sleep "$FAKE_RUNTIME_HANG"
                exit "$FAKE_RUNTIME_EXIT"
                ;;
        esac
        ;;
    *)     exit 0 ;;
esac
EOF
    chmod +x "$bin_dir/podman"
    cp "$bin_dir/podman" "$bin_dir/docker"
    export PATH="$bin_dir:$PATH"
}

# Inject fake jj/git that return a controlled project root.
setup_fake_vcs() {
    local bin_dir="$FIXTURE_DIR/bin"
    mkdir -p "$bin_dir"
    local root="${1:-$FIXTURE_DIR}"

    cat > "$bin_dir/jj" <<EOF
#!/bin/sh
case "\$1" in
  root) echo "$root" ;;
  *) exit 1 ;;
esac
EOF
    chmod +x "$bin_dir/jj"

    cat > "$bin_dir/git" <<EOF
#!/bin/sh
case "\$2" in
  --show-toplevel) echo "$root" ;;
  *) exit 1 ;;
esac
EOF
    chmod +x "$bin_dir/git"
    export PATH="$bin_dir:$PATH"
}

# Write a minimal run.conf into FIXTURE_DIR/commands/run.conf.
write_run_conf() {
    mkdir -p "$FIXTURE_DIR/commands"
    printf '%s\n' "$@" > "$FIXTURE_DIR/commands/run.conf"
}

# Create a command directory with a stub main.sh.
# Usage: setup_command "release/build" [ext]
# Creates commands/<path>/main.<ext> (default: sh).
setup_command() {
    local path="$1"
    local ext="${2:-sh}"
    local dir="$FIXTURE_DIR/commands/$path"
    mkdir -p "$dir"
    printf '#!/bin/sh\n"$@"\n' > "$dir/main.$ext"
    chmod +x "$dir/main.$ext"
}
