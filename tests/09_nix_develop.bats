#!/usr/bin/env bats
# §09 NIX DEVELOP — devShell command forwarding

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "nix develop: uses nix develop --command when flake.nix present" {
    touch "$FIXTURE_DIR/flake.nix"
    run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    grep -q "nix develop" "$FAKE_RUNTIME_LOG"
    grep -q -- "--command" "$FAKE_RUNTIME_LOG"
}

@test "nix develop: falls back to bash entrypoint when no flake.nix" {
    run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    ! grep -q "nix develop" "$FAKE_RUNTIME_LOG"
    grep -q -- "--entrypoint bash" "$FAKE_RUNTIME_LOG"
}

@test "nix develop: uses run-root path in nix develop invocation" {
    touch "$FIXTURE_DIR/flake.nix"
    run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    grep -q "path:$FIXTURE_DIR" "$FAKE_RUNTIME_LOG"
}

@test "nix develop: dry-run reports devshell mode when flake.nix present" {
    touch "$FIXTURE_DIR/flake.nix"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"nix develop"* ]]
    [[ "$stderr" == *"path:$FIXTURE_DIR"* ]]
}

@test "nix develop: dry-run reports direct mode when no flake.nix" {
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"nix develop"* ]]
    [[ "$stderr" == *"image=test:latest"* ]]
}
