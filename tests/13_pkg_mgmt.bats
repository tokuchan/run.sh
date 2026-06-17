#!/usr/bin/env bats
# §13 PACKAGE MANAGEMENT — --search, --add, --remove

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
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
