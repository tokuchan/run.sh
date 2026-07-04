#!/usr/bin/env bats
# §05 COMMAND DISPATCH — command directory dispatch tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
}
teardown() { teardown_fixture; }

# ── behavior 1: root detection ────────────────────────────────────────────

@test "root: commands/run.conf image key is parsed" {
    write_run_conf "image = cmd-image:latest"
    setup_command "echo"
    run --separate-stderr "$RUN_SH" --dry-run echo
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"cmd-image:latest"* ]]
}

@test "root: no commands/run.conf exits 125 with run root error" {
    # Override write_run_conf's work — remove commands/run.conf
    local bin2="$FIXTURE_DIR/bin2"
    mkdir -p "$bin2"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/jj"
    printf '#!/bin/sh\nexit 1\n' > "$bin2/git"
    chmod +x "$bin2/jj" "$bin2/git"
    local tmpdir
    tmpdir="$(mktemp -d)"
    run --separate-stderr env -C "$tmpdir" PATH="$bin2:$PATH" "$RUN_SH" --dry-run echo hi
    rm -rf "$tmpdir"
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"run root"* ]]
}

# ── behavior 2: basic command dispatch ───────────────────────────────────

@test "dispatch: command path resolves main.sh and invokes container" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"main.sh"* ]]
}

@test "dispatch: remaining args are forwarded to main" {
    setup_command "echo"
    run --separate-stderr "$RUN_SH" --dry-run echo one two three
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"one two three"* ]]
}

# ── behavior 3: greedy longest match ─────────────────────────────────────

@test "dispatch: greedy walk reaches deepest matching directory" {
    setup_command "release/build"
    setup_command "release"
    run --separate-stderr "$RUN_SH" --dry-run release build
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"release/build/main.sh"* ]]
}

@test "dispatch: stops at deepest directory that exists" {
    setup_command "release"
    run --separate-stderr "$RUN_SH" --dry-run release build
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"release/main.sh"* ]]
    [[ "$stderr" == *"build"* ]]
}

# ── behavior 4: flag stops the walk ──────────────────────────────────────

@test "dispatch: flag token stops greedy walk" {
    setup_command "release"
    run --separate-stderr "$RUN_SH" --dry-run release --verbose
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"release/main.sh"* ]]
    [[ "$stderr" == *"--verbose"* ]]
}

@test "dispatch: flag before any command path invokes root listing" {
    run --separate-stderr "$RUN_SH" --dry-run
    [ "$status" -eq 0 ]
}

# ── behavior 5: root env inherited ───────────────────────────────────────

@test "config: commands/env vars are injected for all commands" {
    printf 'ROOT_VAR=from_root\n' > "$FIXTURE_DIR/commands/env"
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"ROOT_VAR=from_root"* ]]
}

# ── behavior 6: child env overrides parent ────────────────────────────────

@test "config: child env overrides parent env for same key" {
    printf 'MYVAR=parent\n' > "$FIXTURE_DIR/commands/env"
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf 'MYVAR=child\n' > "$FIXTURE_DIR/commands/hello/env"
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"MYVAR=child"* ]]
    [[ "$stderr" != *"MYVAR=parent"* ]]
}

# ── behavior 7: root mount file inherited ─────────────────────────────────

@test "config: commands/mount mounts appear for all commands" {
    mkdir -p "$FIXTURE_DIR/commands/fs/data"
    printf '/data\n' > "$FIXTURE_DIR/commands/mount"
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"/data"* ]]
}

# ── behavior 8: child mount overrides parent for same container dest ──────

@test "config: child mount overrides parent mount for same container path" {
    mkdir -p "$FIXTURE_DIR/commands/fs/data" \
             "$FIXTURE_DIR/commands/hello/fs/data"
    printf '/data\n' > "$FIXTURE_DIR/commands/mount"
    printf '/data\n' > "$FIXTURE_DIR/commands/hello/mount"
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    # Should appear exactly once (child wins)
    local count
    count="$(printf '%s' "$stderr" | grep -c "/data" || true)"
    [ "$count" -eq 1 ]
}

# ── behavior 8b: leftover run/run.txt is a hard error (ADR-0018) ──────────

@test "config: leftover commands/<cmd>/run exits 125 pointing at the rename" {
    setup_command "hello"
    printf '/data\n' > "$FIXTURE_DIR/commands/hello/run"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"rename it to 'mount'"* ]]
}

@test "config: leftover root commands/run.txt exits 125" {
    setup_command "hello"
    printf '/data\n' > "$FIXTURE_DIR/commands/run.txt"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"rename it to 'mount'"* ]]
}

@test "config: unrecognized line in mount file exits 125 pointing at conf" {
    setup_command "hello"
    printf 'not-a-mount-spec\n' > "$FIXTURE_DIR/commands/hello/mount"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"non-mount settings belong in 'conf'"* ]]
}

# ── behavior 9: no-main fallback ──────────────────────────────────────────

@test "listing: no-main command shows listing and exits 0" {
    mkdir -p "$FIXTURE_DIR/commands/release"
    setup_command "release/build"
    run --separate-stderr "$RUN_SH" release
    [ "$status" -eq 0 ]
    [[ "$output" == *"build"* ]]
}

@test "listing: help.md first paragraph shown before sub-command list" {
    mkdir -p "$FIXTURE_DIR/commands/release"
    printf 'Top of release help.\n\nMore detail.\n' \
        > "$FIXTURE_DIR/commands/release/help.md"
    setup_command "release/build"
    run --separate-stderr "$RUN_SH" release
    [ "$status" -eq 0 ]
    [[ "$output" == *"Top of release help."* ]]
}

# ── behavior 10: --help intercepted at matched directory ──────────────────

@test "help: --help with no command shows runner help" {
    run --separate-stderr "$RUN_SH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"DESCRIPTION"* ]] || [[ "$stderr" == *"DESCRIPTION"* ]]
}

@test "help: --help after command path shows command help.md" {
    setup_command "release"
    printf '# Release\n\nRelease help text.\n' \
        > "$FIXTURE_DIR/commands/release/help.md"
    run --separate-stderr "$RUN_SH" release --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Release help text"* ]]
}

# ── behavior 11: --list-commands ──────────────────────────────────────────

@test "list-commands: outputs slash-separated paths one per line" {
    setup_command "build"
    setup_command "release/package"
    run "$RUN_SH" --list-commands
    [ "$status" -eq 0 ]
    [[ "$output" == *"build"* ]]
    [[ "$output" == *"release/package"* ]]
}

@test "list-commands: includes tab-separated description when help.md present" {
    setup_command "build"
    printf 'Build the project.\n\nMore details.\n' \
        > "$FIXTURE_DIR/commands/build/help.md"
    run "$RUN_SH" --list-commands
    [ "$status" -eq 0 ]
    [[ "$output" == *"build	Build the project."* ]]
}

# ── behavior 12: runner metadata injected ─────────────────────────────────

@test "metadata: RUN_ROOT is injected as env var" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"RUN_ROOT="* ]]
}

@test "metadata: RUN_COMMAND reflects resolved command path" {
    setup_command "release/build"
    run --separate-stderr "$RUN_SH" --dry-run release build
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"RUN_COMMAND=release/build"* ]]
}

@test "metadata: RUN_PROJECT reflects resolved project name" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"RUN_PROJECT="* ]]
}

@test "metadata: RUN_CONTAINER_RUNTIME reflects the detected runtime" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"RUN_CONTAINER_RUNTIME=podman"* ]]
}

@test "metadata: RUN_CONTAINER_IMAGE reflects the configured image" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"RUN_CONTAINER_IMAGE=test:latest"* ]]
}

@test "metadata: missing runtime is still fatal for container-dispatched commands" {
    setup_command "hello"
    rm -f "$FIXTURE_DIR/bin/podman" "$FIXTURE_DIR/bin/docker"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"no container runtime found"* ]]
}

# ── behavior 13: rename warning ───────────────────────────────────────────

@test "rename: no warning when script name matches run root basename" {
    setup_command "hello"
    local link="$FIXTURE_DIR/bin/$(basename "$FIXTURE_DIR")"
    mkdir -p "$FIXTURE_DIR/bin"
    ln -s "$RUN_SH" "$link"
    run --separate-stderr "$link" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"rename"* ]]
}

@test "rename: warns when script is named run.sh in a non-run.sh project" {
    setup_command "hello"
    # FIXTURE_DIR basename won't be "run.sh", so invoking as run.sh should warn
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"rename"* ]] || [[ "$stderr" == *"script name"* ]]
}

# ── behavior 14: main.<ext> probe order ───────────────────────────────────

@test "probe: main (no ext) is preferred over main.sh" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\necho hi\n' > "$FIXTURE_DIR/commands/hello/main"
    chmod +x "$FIXTURE_DIR/commands/hello/main"
    printf '#!/bin/sh\necho hi\n' > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" != *"main.sh"* ]]
    [[ "$stderr" == *"hello/main"* ]] && [[ "$stderr" != *"hello/main."* ]]
}

@test "probe: main.sh is found when no extension-free main exists" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"main.sh"* ]]
}

# ── behavior 15: --init-commands scaffolds commands/ skeleton ─────────────

@test "init: --init-commands creates commands/ skeleton" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-commands"
    [ "$status" -eq 0 ]
    [ -d "$FIXTURE_DIR/commands" ]
    [ -f "$FIXTURE_DIR/commands/.gitignore" ]
    [ -f "$FIXTURE_DIR/commands/help.md" ]
}

@test "init: --init-commands gitignore contains **/fs/" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-commands"
    [ "$status" -eq 0 ]
    grep -qF '**/fs/' "$FIXTURE_DIR/commands/.gitignore"
}

@test "init: --init-config writes commands/run.conf" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init-config"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/commands/run.conf" ]
    grep -q "image" "$FIXTURE_DIR/commands/run.conf"
}

@test "init: --init writes all four artifacts" {
    run bash -c "cd \"$FIXTURE_DIR\" && \"$RUN_SH\" --init"
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/Dockerfile" ]
    [ -f "$FIXTURE_DIR/flake.nix" ]
    [ -f "$FIXTURE_DIR/commands/run.conf" ]
    [ -d "$FIXTURE_DIR/commands" ]
}
