#!/usr/bin/env bats
# §01 HELP PAGER & SGR — auto-paging and terminal formatting for --help

load helpers/setup

setup() { setup_fixture; }
teardown() { teardown_fixture; }

# Helper: write a fake pager to FIXTURE_DIR/bin that records invocation.
# Sets FAKE_PAGER (path) and FAKE_PAGER_LOG (sentinel file).
setup_fake_pager() {
    mkdir -p "$FIXTURE_DIR/bin"
    FAKE_PAGER="$FIXTURE_DIR/bin/fakepager"
    FAKE_PAGER_LOG="$FIXTURE_DIR/pager.log"
    cat > "$FAKE_PAGER" <<EOF
#!/bin/sh
printf 'called\n' > "$FAKE_PAGER_LOG"
cat
EOF
    chmod +x "$FAKE_PAGER"
    export FAKE_PAGER FAKE_PAGER_LOG
}

# ── Pager invocation ──────────────────────────────────────────────────────────

@test "help: pager invoked when stdout is a TTY" {
    setup_fake_pager
    script -q -c "PAGER=$FAKE_PAGER $RUN_SH --help" /dev/null
    [ -f "$FAKE_PAGER_LOG" ]
}

@test "help: no pager when stdout is not a TTY" {
    setup_fake_pager
    PAGER="$FAKE_PAGER" run "$RUN_SH" --help
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_PAGER_LOG" ]
}
