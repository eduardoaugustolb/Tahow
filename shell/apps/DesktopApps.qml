import ".." as Tahow
import QtQuick
import Quickshell

Scope {
    id: root

    function closeWindows() {
        files.active = false;
        calendar.active = false;
    }

    function open(app) {
        switch (app) {
        case "files":
            files.active = true;
            files.item?.requestActivate();
            break;
        case "calendar":
            calendar.active = true;
            calendar.item?.requestActivate();
            break;
        case "terminal":
            const dark = tones.darkAppearance;
            Quickshell.execDetached(["sh", "-c",
                'if command -v kitty >/dev/null; then exec kitty -o "background=$1" -o "foreground=$2" -o "selection_background=$3" -o "selection_foreground=$4" -o "cursor=$3" -o "window_padding_width=14"; fi\n' +
                'for terminal in xdg-terminal-exec foot konsole gnome-terminal alacritty xterm; do\n' +
                '    if command -v "$terminal" >/dev/null; then exec "$terminal"; fi\n' +
                'done\n' +
                'if command -v notify-send >/dev/null; then notify-send -- "$5" "$6"; fi',
                "tahow-terminal", dark ? "#191c25" : "#f5f7fb", dark ? "#e7eaf3" : "#1d2430",
                Tahow.Theme.alpha(tones.highlight, 1).toString(), tones.highlightedText.toString(), Tahow.I18n.tr("Terminal"),
                Tahow.I18n.tr("No terminal emulator found")]);
            break;
        }
    }

    Tahow.SettingsControls.Colors { id: tones }

    LazyLoader {
        id: files
        DesktopAppWindow {
            title: Tahow.I18n.tr("Files")
            width: 700
            height: 500
            onDismissed: files.active = false
            body: DesktopFiles {}
        }
    }

    LazyLoader {
        id: calendar
        DesktopAppWindow {
            title: Tahow.I18n.tr("Calendar")
            width: 670
            height: 520
            onDismissed: calendar.active = false
            body: DesktopCalendar {}
        }
    }
}
