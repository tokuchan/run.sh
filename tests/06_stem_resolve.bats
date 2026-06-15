#!/usr/bin/env bats
# §05 STEM RESOLUTION — stem name resolution tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
}
teardown() { teardown_fixture; }

@test "stem: first positional arg is used as stem when script is 'run.sh'" {
    printf 'MYSTEM_VAR=1\n' > "$FIXTURE_DIR/mystem.env"
    run --separate-stderr "$RUN_SH" --dry-run mystem echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"MYSTEM_VAR=1"* ]]
}

@test "stem: symlink name overrides first positional arg as stem" {
    local link="$FIXTURE_DIR/bin/mystem"
    mkdir -p "$FIXTURE_DIR/bin"
    ln -s "$RUN_SH" "$link"
    printf 'SYMLINK_VAR=1\n' > "$FIXTURE_DIR/mystem.env"
    run --separate-stderr "$link" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"SYMLINK_VAR=1"* ]]
}

@test "stem: default stem is loaded even when no explicit stem is given" {
    printf 'DEFAULT_VAR=1\n' > "$FIXTURE_DIR/default.env"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"DEFAULT_VAR=1"* ]]
}

@test "stem: -s option loads an additional stem" {
    printf 'EXTRA_VAR=1\n' > "$FIXTURE_DIR/extra.env"
    run --separate-stderr "$RUN_SH" -s extra --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"EXTRA_VAR=1"* ]]
}
