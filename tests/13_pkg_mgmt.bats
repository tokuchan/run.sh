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
