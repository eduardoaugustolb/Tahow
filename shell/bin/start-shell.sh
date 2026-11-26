#!/bin/sh
# Tahow Shell launcher — starts the shell detached from any terminal.
#
# Running quickshell as a plain background job (`qs -p ... &`) makes it part of
# the calling shell's session: the first `exit` warns about active jobs and the
# second one sends SIGHUP, taking the whole desktop shell down with it.
# `--daemonize` detaches with setsid and `--no-duplicate` makes repeated calls
# (Hyprland exec-once, autostart hooks, keybinds) safe and idempotent.
set -eu

shell_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config="$shell_dir/shell.qml"

if command -v qs >/dev/null 2>&1; then
    qs_bin=qs
elif command -v quickshell >/dev/null 2>&1; then
    qs_bin=quickshell
else
    printf 'start-shell: quickshell (qs) not found in PATH\n' >&2
    exit 127
fi

running() {
    "$qs_bin" list -p "$config" >/dev/null 2>&1
}

if running; then
    exit 0
fi

if "$qs_bin" --help 2>&1 | grep -q -- '--daemonize'; then
    "$qs_bin" -n -d -p "$config" >/dev/null 2>&1 || true
else
    # Older builds: a session of our own is what protects the shell from the
    # caller's terminal, so `setsid` is required here rather than `disown`.
    setsid "$qs_bin" -n -p "$config" >/dev/null 2>&1 </dev/null &
fi

attempt=0
while [ "$attempt" -lt 50 ]; do
    if running; then
        exit 0
    fi
    sleep 0.1
    attempt=$((attempt + 1))
done

printf 'start-shell: Tahow Shell did not start; check `%s log`\n' "$qs_bin" >&2
exit 1
