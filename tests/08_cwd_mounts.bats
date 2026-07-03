#!/usr/bin/env bats
# §06 MOUNT CONSTRUCTION — CWD and project root mirror tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "cwd: current directory appears as a mount in dry-run" {
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"$PWD"* ]]
}

@test "cwd: project root appears as a mount in dry-run" {
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"$FIXTURE_DIR"* ]]
}

@test "cwd: --no-cwd suppresses CWD and project root mounts" {
    run --separate-stderr "$RUN_SH" --no-cwd --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"$PWD:"* ]]
}

@test "mirror: --mirror path appears as rw mount in dry-run" {
    local target
    target="$(mktemp -d)"
    run --separate-stderr "$RUN_SH" --mirror "$target" --dry-run echo hi
    rmdir "$target"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"${target}:${target}"* ]]
}

@test "mirror: --mirror-ro path appears as ro mount in dry-run" {
    local target
    target="$(mktemp -d)"
    run --separate-stderr "$RUN_SH" --mirror-ro "$target" --dry-run echo hi
    rmdir "$target"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"${target}:${target}:ro"* ]]
}
