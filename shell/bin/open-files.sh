#!/bin/sh
set -eu

home_folder=$1
desktop_profile=$2
handler=$(xdg-mime query default inode/directory 2>/dev/null || true)
case "$handler" in
    ''|org.kde.dolphin.desktop)
        if [ -f "$desktop_profile/kdeglobals" ] && command -v dolphin >/dev/null 2>&1; then
            export XDG_CONFIG_HOME="$desktop_profile"
            if [ -f "$desktop_profile/qt6ct/qt6ct.conf" ]; then
                export QT_QPA_PLATFORMTHEME=qt6ct
            fi
            exec dolphin --new-window "$home_folder"
        fi
        ;;
esac
exec xdg-open "$home_folder"
