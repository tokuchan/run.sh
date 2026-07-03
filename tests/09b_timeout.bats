#!/usr/bin/env bats
# §09 CONTAINER INVOCATION — run-time limit (--timeout)

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "timeout: --timeout N appears in dry-run output" {
    run --separate-stderr "$RUN_SH" --timeout 30 --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"timeout=30s"* ]]
}

@test "timeout: exits 124 when container exceeds timeout" {
    FAKE_RUNTIME_HANG=5 run "$RUN_SH" --timeout 1 echo hi
    [ "$status" -eq 124 ]
}

@test "timeout: propagates exit code when command finishes before timeout" {
    FAKE_RUNTIME_EXIT=42 run "$RUN_SH" --timeout 30 echo hi
    [ "$status" -eq 42 ]
}

@test "timeout: --tty with --timeout warns and runs without TTY" {
    run --separate-stderr "$RUN_SH" --tty --timeout 30 --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"--tty ignored"* ]]
}

@test "timeout: timeout key in run.conf is accepted" {
    write_run_conf "image = test:latest" "timeout = 30"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"timeout=30s"* ]]
}

@test "timeout: --timeout 0 at CLI disables timeout from run.conf" {
    write_run_conf "image = test:latest" "timeout = 30"
    run --separate-stderr "$RUN_SH" --timeout 0 --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"timeout="* ]]
}
