#!/usr/bin/env bats
# §03 CONFIGURATION tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "run.conf: unknown key exits 125 with error message" {
    write_run_conf "typo_key = bad"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"unknown key"* ]]
    [[ "$stderr" == *"typo_key"* ]]
}

@test "run.conf: image key is accepted and appears in dry-run" {
    write_run_conf "image = test-image:latest"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"test-image:latest"* ]]
}

@test "run.conf: comment lines and blank lines are ignored" {
    write_run_conf \
        "# this is a comment" \
        "" \
        "image = my-img:1.0"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"my-img:1.0"* ]]
}

@test "run.conf: missing commands/run.conf when no VCS root exits 125" {
    local bin2="$FIXTURE_DIR/bin2"
    mkdir -p "$bin2"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/jj"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/git"
    chmod +x "$bin2/jj" "$bin2/git"
    local tmpdir
    tmpdir="$(mktemp -d)"
    run --separate-stderr env -C "$tmpdir" PATH="$bin2:$PATH" "$RUN_SH" --dry-run echo hi
    rm -rf "$tmpdir"
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"run root"* ]]
}
