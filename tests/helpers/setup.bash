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
setup_fake_runtime() {
    local bin_dir="$FIXTURE_DIR/bin"
    mkdir -p "$bin_dir"
    FAKE_RUNTIME_LOG="$FIXTURE_DIR/runtime.log"
    FAKE_RUNTIME_EXIT="${FAKE_RUNTIME_EXIT:-0}"
    export FAKE_RUNTIME_LOG FAKE_RUNTIME_EXIT

    cat > "$bin_dir/podman" <<'EOF'
#!/bin/sh
echo "$@" >> "$FAKE_RUNTIME_LOG"
exit "$FAKE_RUNTIME_EXIT"
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

# Write a minimal run.conf into FIXTURE_DIR.
write_run_conf() {
    printf '%s\n' "$@" > "$FIXTURE_DIR/run.conf"
}
