#!/usr/bin/env bats
# §05 STEM RESOLUTION — .env file parsing tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
}
teardown() { teardown_fixture; }

@test ".env: KEY=VALUE pairs are injected into dry-run" {
    printf 'FOO=bar\nBAZ=qux\n' > "$FIXTURE_DIR/default.env"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"FOO=bar"* ]]
    [[ "$stderr" == *"BAZ=qux"* ]]
}

@test ".env: comment lines are ignored" {
    printf '# this is a comment\nKEY=value\n' > "$FIXTURE_DIR/default.env"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"# this"* ]]
    [[ "$stderr" == *"KEY=value"* ]]
}

@test ".env: blank lines are ignored" {
    printf '\nKEY=value\n\n' > "$FIXTURE_DIR/default.env"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"KEY=value"* ]]
}

@test ".env: missing file is silently ignored" {
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
}
