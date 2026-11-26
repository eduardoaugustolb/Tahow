#!/bin/sh
set -eu

case "${1:-}" in
    lock) target=tahoeLock ;;
    launcher|settings|clipboard|emojis|capture|files) target=tahoe ;;
    *) exit 2 ;;
esac
action=$1

shell_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
call() {
    response=$(qs -p "$shell_dir/shell.qml" ipc call "$target" "$action" 2>&1) || {
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
