#!/usr/bin/env bats
# §07 IMAGE MANAGEMENT — auto-build, auto-rebuild, clean, force-rebuild

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

# ── --clean ───────────────────────────────────────────────────────────────
@test "clean: --clean runs rmi and exits 0" {
    run "$RUN_SH" --clean echo hi
    [ "$status" -eq 0 ]
    grep -q "rmi test:latest" "$FAKE_RUNTIME_LOG"
}

@test "clean: --clean warns and exits 0 when image absent" {
    FAKE_IMAGE_EXISTS=0 run --separate-stderr "$RUN_SH" --clean echo hi
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"not found"* ]]
}

# ── auto-build ────────────────────────────────────────────────────────────
@test "auto-build: builds image when absent before running command" {
    FAKE_IMAGE_EXISTS=0 run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    grep -q "build" "$FAKE_RUNTIME_LOG"
}

@test "auto-build: --no-build exits 125 when image absent" {
    FAKE_IMAGE_EXISTS=0 run "$RUN_SH" --no-build echo hi
    [ "$status" -eq 125 ]
}

@test "auto-build: skips build when image already present" {
    FAKE_IMAGE_EXISTS=1 run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    ! grep -q "^build " "$FAKE_RUNTIME_LOG" 2>/dev/null || \
        ! grep -q "build.*test:latest" "$FAKE_RUNTIME_LOG"
}

# ── auto-rebuild ──────────────────────────────────────────────────────────
@test "auto-rebuild: rebuilds when Dockerfile fingerprint differs from label" {
    touch "$FIXTURE_DIR/Dockerfile"
    FAKE_IMAGE_EXISTS=1 FAKE_IMAGE_FINGERPRINT="old-hash" \
        run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    grep -q "build" "$FAKE_RUNTIME_LOG"
}

@test "auto-rebuild: skips rebuild when fingerprint matches" {
    touch "$FIXTURE_DIR/Dockerfile"
    local current_fp
    current_fp="$(sha256sum "$FIXTURE_DIR/Dockerfile" | cut -d' ' -f1)"
    FAKE_IMAGE_EXISTS=1 FAKE_IMAGE_FINGERPRINT="$current_fp" \
        run "$RUN_SH" echo hi
    [ "$status" -eq 0 ]
    ! grep -q "^build " "$FAKE_RUNTIME_LOG" 2>/dev/null
}

@test "auto-rebuild: --no-rebuild suppresses rebuild but not build on absent image" {
    FAKE_IMAGE_EXISTS=0 run "$RUN_SH" --no-rebuild echo hi
    [ "$status" -eq 0 ]
    grep -q "build" "$FAKE_RUNTIME_LOG"
}

@test "auto-rebuild: --force-rebuild rebuilds unconditionally" {
    local current_fp
    touch "$FIXTURE_DIR/Dockerfile"
    current_fp="$(sha256sum "$FIXTURE_DIR/Dockerfile" | cut -d' ' -f1)"
    FAKE_IMAGE_EXISTS=1 FAKE_IMAGE_FINGERPRINT="$current_fp" \
        run "$RUN_SH" --force-rebuild echo hi
    [ "$status" -eq 0 ]
    grep -q "build" "$FAKE_RUNTIME_LOG"
}
