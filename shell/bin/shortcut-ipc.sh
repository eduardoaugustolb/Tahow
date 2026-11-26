#!/bin/sh
set -eu

case "${1:-}" in
    launcher|settings|clipboard|emojis|capture) action=$1 ;;
    *) exit 2 ;;
esac

shell_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
call() {
    response=$(qs -p "$shell_dir/shell.qml" ipc call tahoe "$action" 2>&1) || {
        printf '%s\n' "$response" >&2
        return 1
    }
    case "$response" in
        *"Not ready to accept queries yet."*) return 1 ;;
    esac
}

if call >/dev/null 2>&1; then
    exit 0
fi

qs -n -d -p "$shell_dir/shell.qml"
attempt=0
while [ "$attempt" -lt 50 ]; do
    sleep 0.1
    if call >/dev/null 2>&1; then
        exit 0
    fi
    attempt=$((attempt + 1))
done

call
