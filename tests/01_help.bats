#!/usr/bin/env bats
# §01 HELP & USAGE tests

load helpers/setup

setup() { setup_fixture; }
teardown() { teardown_fixture; }

@test "no args prints cheat sheet and exits 0" {
    run "$RUN_SH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--help"* ]]
}

@test "no args with no discoverable run root shows cheat sheet only, no error" {
    local bin2="$FIXTURE_DIR/bin2"
    mkdir -p "$bin2"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/jj"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/git"
    chmod +x "$bin2/jj" "$bin2/git"
    local tmpdir
    tmpdir="$(mktemp -d)"
    run env -C "$tmpdir" PATH="$bin2:$PATH" "$RUN_SH"
    rm -rf "$tmpdir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" != *"Commands:"* ]]
}

@test "no args with a run root appends command listing after the cheat sheet" {
    setup_fake_vcs "$FIXTURE_DIR"
    write_run_conf "image = test:latest"
    setup_command "hello"
    run "$RUN_SH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Commands:"* ]]
    [[ "$output" == *"hello"* ]]
}

@test "--help prints full manual and exits 0" {
    run "$RUN_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"DESCRIPTION"* ]]
    [[ "$output" == *"OPTIONS"* ]]
    [[ "$output" == *"EXAMPLES"* ]]
}
