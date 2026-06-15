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

@test "--help prints full manual and exits 0" {
    run "$RUN_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"DESCRIPTION"* ]]
    [[ "$output" == *"OPTIONS"* ]]
    [[ "$output" == *"EXAMPLES"* ]]
}
