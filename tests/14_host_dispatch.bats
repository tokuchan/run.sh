#!/usr/bin/env bats
# §05/§09 HOST DISPATCH — commands/<cmd>/conf `dispatch = host|container` tests

load helpers/setup

setup() {
    setup_fixture
    setup_fake_vcs "$FIXTURE_DIR"
    setup_fake_runtime
    write_run_conf "image = test:latest"
}
teardown() { teardown_fixture; }

# ── conf parsing ──────────────────────────────────────────────────────────

@test "conf: unknown key exits 125 with error message" {
    setup_command "hello"
    printf 'typo_key = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"unknown key"* ]]
    [[ "$stderr" == *"typo_key"* ]]
}

@test "conf: invalid dispatch value exits 125 with error message" {
    setup_command "hello"
    printf 'dispatch = nowhere\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 125 ]
    [[ "$stderr" == *"invalid dispatch value"* ]]
}

@test "conf: comment and blank lines are ignored" {
    setup_command "hello"
    printf '# a comment\n\ndispatch = container\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
}

# ── default is container ──────────────────────────────────────────────────

@test "dispatch: default is container when no conf file present" {
    setup_command "hello"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"dry-run image="* ]]
}

# ── host dispatch: dry-run ─────────────────────────────────────────────────

@test "dispatch: host conf shows host command line in dry-run, not container invocation" {
    setup_command "hello"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"dry-run host command:"* ]]
    [[ "$stderr" != *"dry-run image="* ]]
}

# ── host dispatch: real execution ─────────────────────────────────────────

@test "dispatch: host conf execs main directly on host, bypassing the container runtime" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\necho ran-on-host\n' > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run "$RUN_SH" hello
    [ "$status" -eq 0 ]
    [[ "$output" == *"ran-on-host"* ]]
    [ ! -f "$FAKE_RUNTIME_LOG" ]
}

@test "dispatch: host command exit code is propagated" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\nexit 7\n' > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run "$RUN_SH" hello
    [ "$status" -eq 7 ]
}

@test "dispatch: host conf exports commands/env vars and runner metadata into host env" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\nprintf "%%s %%s\\n" "$MYVAR" "$RUN_COMMAND"\n' \
        > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'MYVAR=from_env_file\n' > "$FIXTURE_DIR/commands/hello/env"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run "$RUN_SH" hello
    [ "$status" -eq 0 ]
    [[ "$output" == *"from_env_file hello"* ]]
}

@test "dispatch: host command receives RUN_CONTAINER_RUNTIME and RUN_CONTAINER_IMAGE" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\nprintf "runtime=%%s image=%%s\\n" "$RUN_CONTAINER_RUNTIME" "$RUN_CONTAINER_IMAGE"\n' \
        > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run "$RUN_SH" hello
    [ "$status" -eq 0 ]
    [[ "$output" == *"runtime=podman image=test:latest"* ]]
}

@test "dispatch: host command works with no container runtime installed" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\nprintf "runtime=[%%s]\\n" "$RUN_CONTAINER_RUNTIME"\n' \
        > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    rm -f "$FIXTURE_DIR/bin/podman" "$FIXTURE_DIR/bin/docker"
    run "$RUN_SH" hello
    [ "$status" -eq 0 ]
    [[ "$output" == *"runtime=[]"* ]]
}

@test "dispatch: remaining args are forwarded to host-dispatched main" {
    mkdir -p "$FIXTURE_DIR/commands/hello"
    printf '#!/bin/sh\necho "args: $*"\n' > "$FIXTURE_DIR/commands/hello/main.sh"
    chmod +x "$FIXTURE_DIR/commands/hello/main.sh"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run "$RUN_SH" hello one two
    [ "$status" -eq 0 ]
    [[ "$output" == *"args: one two"* ]]
}

# ── inheritance ────────────────────────────────────────────────────────────

@test "dispatch: child inherits host from parent conf" {
    setup_command "release/build"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/release/conf"
    run --separate-stderr "$RUN_SH" --dry-run release build
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"dry-run host command:"* ]]
}

@test "dispatch: child conf overrides parent host back to container" {
    setup_command "release/build"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/release/conf"
    printf 'dispatch = container\n' > "$FIXTURE_DIR/commands/release/build/conf"
    run --separate-stderr "$RUN_SH" --dry-run release build
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"dry-run image="* ]]
}

# ── container-only flags warn instead of silently no-op ───────────────────

@test "dispatch: --mirror is ignored with a warning for host-dispatched commands" {
    setup_command "hello"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run --mirror "$FIXTURE_DIR" hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"--mirror ignored"* ]]
}

@test "dispatch: --timeout is ignored with a warning for host-dispatched commands" {
    setup_command "hello"
    printf 'dispatch = host\n' > "$FIXTURE_DIR/commands/hello/conf"
    run --separate-stderr "$RUN_SH" --dry-run --timeout 5 hello
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"--timeout ignored"* ]]
}
