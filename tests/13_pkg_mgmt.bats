#!/usr/bin/env bats
# §13 PACKAGE MANAGEMENT — --search, --add, --remove

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
    setup_command "echo"
}
teardown() { teardown_fixture; }

# Helper: write a flake.nix with the run:packages sentinel
write_flake() {
    cat > "$FIXTURE_DIR/flake.nix" <<'FLAKE'
{ outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = (import nixpkgs {}).mkShell {
      packages = with (import nixpkgs {}); [
        bash
        # run:packages — managed by 'run --add / --remove'; do not delete this line
      ];
    };
  };
}
FLAKE
}

# ── --search ──────────────────────────────────────────────────────────────────
@test "search: --search runs nix search nixpkgs inside container" {
    run "$RUN_SH" --search nodejs
    [ "$status" -eq 0 ]
    grep -q "nix search nixpkgs nodejs" "$FAKE_RUNTIME_LOG"
}

# ── --add ─────────────────────────────────────────────────────────────────────
@test "add: --add inserts package above sentinel in flake.nix" {
    write_flake
    run "$RUN_SH" --add ripgrep
    [ "$status" -eq 0 ]
    grep -q "ripgrep" "$FIXTURE_DIR/flake.nix"
    # ripgrep must appear before the sentinel
    grep -n "ripgrep\|run:packages" "$FIXTURE_DIR/flake.nix" \
        | awk -F: '{print NR, $1}' \
        | awk 'NR==1{rg=$2} NR==2{sentinel=$2} END{exit (rg < sentinel) ? 0 : 1}'
}

@test "add: --add exits 125 when package not in nixpkgs" {
    write_flake
    FAKE_NIX_EVAL_EXIT=1 run "$RUN_SH" --add not-a-real-package
    [ "$status" -eq 125 ]
    ! grep -q "not-a-real-package" "$FIXTURE_DIR/flake.nix"
}

@test "add: --add is idempotent when package already in flake.nix" {
    write_flake
    run "$RUN_SH" --add bash
    [ "$status" -eq 0 ]
    # bash should appear exactly once (not duplicated)
    [ "$(grep -c "^[[:space:]]*bash[[:space:]]*$" "$FIXTURE_DIR/flake.nix")" -eq 1 ]
}

@test "add: --add prints pre-warm suggestion after inserting package" {
    write_flake
    run bash -c "$RUN_SH --add ripgrep 2>&1"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "run true"
}

@test "add: --add is repeatable — two --add flags both insert packages" {
    write_flake
    run "$RUN_SH" --add ripgrep --add fd
    [ "$status" -eq 0 ]
    grep -q "ripgrep" "$FIXTURE_DIR/flake.nix"
    grep -q "[[:space:]]fd$" "$FIXTURE_DIR/flake.nix"
}

# ── --remove ──────────────────────────────────────────────────────────────────
@test "remove: --remove deletes package line from flake.nix" {
    write_flake
    run "$RUN_SH" --remove bash
    [ "$status" -eq 0 ]
    ! grep -qE "^[[:space:]]+bash[[:space:]]*$" "$FIXTURE_DIR/flake.nix"
}

@test "remove: --remove is a no-op when package not in flake.nix" {
    write_flake
    run "$RUN_SH" --remove not-there
    [ "$status" -eq 0 ]
}

@test "add: --add exits 125 when sentinel comment is missing" {
    cat > "$FIXTURE_DIR/flake.nix" <<'FLAKE'
{ outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = (import nixpkgs {}).mkShell {
      packages = with (import nixpkgs {}); [ bash ];
    };
  };
}
FLAKE
    run "$RUN_SH" --add ripgrep
    [ "$status" -eq 125 ]
}

# ── --init-flake ───────────────────────────────────────────────────────────────
@test "init-flake: --init-flake writes flake.nix containing run:packages sentinel" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-flake"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/flake.nix" ]
    grep -q "# run:packages" "$FIXTURE_DIR/flake.nix"
}
