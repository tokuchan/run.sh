#!/usr/bin/env bats
# §07 NIX STORE MOUNT — shared and local mode

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

@test "nix store: shared mode mounts XDG cache path at /nix in dry-run" {
    mkdir -p "$FIXTURE_DIR/cache/run/nix"
    touch "$FIXTURE_DIR/cache/run/nix/.keep"
    XDG_CACHE_HOME="$FIXTURE_DIR/cache" \
        run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"$FIXTURE_DIR/cache/run/nix:/nix"* ]]
}

@test "nix store: local mode mounts commands/fs/nix at /nix in dry-run" {
    write_run_conf "image = test:latest
store = local"
    mkdir -p "$FIXTURE_DIR/commands/fs/nix"
    touch "$FIXTURE_DIR/commands/fs/nix/.keep"
    run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"$FIXTURE_DIR/commands/fs/nix:/nix"* ]]
}

@test "nix store: shared mode creates cache directory if absent" {
    local cache_dir="$FIXTURE_DIR/cache/run/nix"
    XDG_CACHE_HOME="$FIXTURE_DIR/cache" \
        run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    [ -d "$cache_dir" ]
}

@test "nix store: seeds store from image on first use" {
    XDG_CACHE_HOME="$FIXTURE_DIR/cache" \
        run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    grep -q -- "--volume.*:/nix-host" "$FAKE_RUNTIME_LOG"
}

@test "nix store: does not seed store when already populated" {
    mkdir -p "$FIXTURE_DIR/cache/run/nix"
    touch "$FIXTURE_DIR/cache/run/nix/.keep"
    XDG_CACHE_HOME="$FIXTURE_DIR/cache" \
        run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    ! grep -q -- ":/nix-host" "$FAKE_RUNTIME_LOG"
}

@test "nix store: skips seeding in dry-run mode" {
    XDG_CACHE_HOME="$FIXTURE_DIR/cache" \
        run --separate-stderr "$RUN_SH" --dry-run echo hi
    [ "$status" -eq 0 ]
    ! grep -q -- ":/nix-host" "$FAKE_RUNTIME_LOG"
}
