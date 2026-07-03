#!/usr/bin/env bats
# §09 CONTAINER INVOCATION — exit code propagation tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "exit: container exit code 0 is propagated" {
    FAKE_RUNTIME_EXIT=0 run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
}

@test "exit: container exit code 1 is propagated" {
    FAKE_RUNTIME_EXIT=1 run "$RUN_SH" echo hi
    [ "$status" -eq 1 ]
}

@test "exit: container exit code 42 is propagated" {
    FAKE_RUNTIME_EXIT=42 run "$RUN_SH" echo hi
    [ "$status" -eq 42 ]
}

@test "exit: run.sh own error exits 125" {
    write_run_conf "bad_key = value"
    run "$RUN_SH" echo hi
    [ "$status" -eq 125 ]
}
