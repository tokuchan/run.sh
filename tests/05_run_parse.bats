#!/usr/bin/env bats
# §05 STEM RESOLUTION — .run file parsing tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
}
teardown() { teardown_fixture; }

@test ".run: container-side paths appear as mounts in dry-run" {
    printf '/nix/store\n/usr/local\n' > "$FIXTURE_DIR/default.run"
    mkdir -p "$FIXTURE_DIR/fs/default/nix/store" \
             "$FIXTURE_DIR/fs/default/usr/local"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"/nix/store"* ]]
    [[ "$stderr" == *"/usr/local"* ]]
}

@test ".run: comment lines and blank lines are ignored" {
    printf '# comment\n\n/nix/store\n' > "$FIXTURE_DIR/default.run"
    mkdir -p "$FIXTURE_DIR/fs/default/nix/store"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"# comment"* ]]
    [[ "$stderr" == *"/nix/store"* ]]
}

@test ".run: missing file is silently ignored" {
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
}

@test ".run: @include pulls in another stem's .run and .env" {
    printf '@include nix\n' > "$FIXTURE_DIR/default.run"
    printf '/nix/store\n' > "$FIXTURE_DIR/nix.run"
    printf 'NIX_PATH=/nix\n' > "$FIXTURE_DIR/nix.env"
    mkdir -p "$FIXTURE_DIR/fs/nix/nix/store"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"/nix/store"* ]]
    [[ "$stderr" == *"NIX_PATH=/nix"* ]]
}
