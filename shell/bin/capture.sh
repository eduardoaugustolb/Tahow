#!/bin/sh
set -eu

mode=${1:-}
case "$mode" in
    screenshot|record) ;;
    select)
        sleep 0.25
        # Slurp reads candidate rectangles to EOF if stdin is a pipe.
        exec slurp -b 00000033 -s 00000000 -c 36a3ffff -w 2 -d </dev/null
        ;;
    colour) sleep 0.25; exec hyprpicker -a ;;
    *) exit 2 ;;
esac
scope=${2:-}
audio=${3:-silent}
geometry=${4:-}
case "$scope" in
    region|screen|window) ;;
    *) exit 2 ;;
esac

# Give the compositor a frame to remove the toolbar.
sleep 0.25
set --
case "$scope" in
    region)
        if [ -z "$geometry" ]; then
            command -v slurp >/dev/null || exit 1
            geometry=$(sh "$0" select) || exit 3
        fi
        [ -n "$geometry" ] || exit 3
        set -- -g "$geometry"
        ;;
    window)
        area=$(hyprctl -j activewindow | jq -er 'select(.address and .size[0] > 0 and .size[1] > 0) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') || exit 1
        set -- -g "$area"
        ;;
    screen)
        output=$(hyprctl -j monitors | jq -er '.[] | select(.focused) | .name') || exit 1
        set -- -o "$output"
        ;;
esac

if [ "$mode" = screenshot ]; then
    pictures=$(xdg-user-dir PICTURES 2>/dev/null || printf '%s/Pictures' "$HOME")
    dir="$pictures/Screenshots"
    mkdir -p -- "$dir"
    shot=$(mktemp --suffix=.png "$dir/Tahow-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
    if ! grim "$@" "$shot"; then
        rm -f -- "$shot"
        exit 1
    fi
    printf '%s\n' "$shot"
    wl-copy --type image/png < "$shot"
else
    command -v wf-recorder >/dev/null || exit 1
    if [ "$audio" = audio ]; then set -- --audio "$@"; fi
    videos=$(xdg-user-dir VIDEOS 2>/dev/null || printf '%s/Videos' "$HOME")
    dir="$videos/Recordings"
    mkdir -p -- "$dir"
    video=$(mktemp --suffix=.mp4 "$dir/Tahow-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
    printf '%s\n' "$video"
    exec wf-recorder --overwrite "$@" -f "$video"
fi
