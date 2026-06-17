#!/usr/bin/env bats
# §01 INIT — stub file generation tests

load helpers/setup

setup() { setup_fixture; }
teardown() { teardown_fixture; }

# ── tracer bullet ──────────────────────────────────────────────────────────
@test "init: --init-container writes Dockerfile to CWD and exits 0" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-container"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/Dockerfile" ]
}

@test "init: --init-container warns and skips existing Dockerfile" {
    printf 'existing\n' > "$FIXTURE_DIR/Dockerfile"
    run --separate-stderr bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-container"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"Dockerfile already exists"* ]]
    [ "$(cat "$FIXTURE_DIR/Dockerfile")" = "existing" ]
}

@test "init: --init-flake writes flake.nix to CWD" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-flake"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/flake.nix" ]
    grep -q "devShells" "$FIXTURE_DIR/flake.nix"
}

@test "init: --init-config writes run.conf to CWD" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-config"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/run.conf" ]
    grep -q "image" "$FIXTURE_DIR/run.conf"
}

@test "init: --init-container appends gitignore entries" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-container"
    [ "$status" -eq 0 ]
    grep -qF "fs/default/nix/" "$FIXTURE_DIR/.gitignore"
    grep -qF "result" "$FIXTURE_DIR/.gitignore"
}

@test "init: --init-container does not duplicate existing gitignore entries" {
    printf 'fs/default/nix/\nresult\n' > "$FIXTURE_DIR/.gitignore"
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-container"
    [ "$status" -eq 0 ]
    [ "$(grep -c "fs/default/nix/" "$FIXTURE_DIR/.gitignore")" -eq 1 ]
    [ "$(grep -c "^result$" "$FIXTURE_DIR/.gitignore")" -eq 1 ]
}

@test "init: --init writes all three files" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/Dockerfile" ]
    [ -f "$FIXTURE_DIR/flake.nix" ]
    [ -f "$FIXTURE_DIR/run.conf" ]
}

@test "init: individual --init-* flags are independent" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-flake"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/flake.nix" ]
    [ ! -f "$FIXTURE_DIR/Dockerfile" ]
    [ ! -f "$FIXTURE_DIR/run.conf" ]
}
