import ".." as Tahow
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    function closeWindows() {
        files.active = false;
        calendar.active = false;
    }

    function open(app) {
        switch (app) {
        case "files":
            if (!Tahow.Config.general.useSystemFileManager) openInternalFiles();
            else if (openHome.running) openHome.startDetached();
            else openHome.running = true;
            break;
        case "calendar":
            calendar.active = true;
            calendar.item?.requestActivate();
            break;
        case "terminal":
            const dark = tones.darkAppearance;
            Quickshell.execDetached(["sh", "-c",
                'if command -v kitty >/dev/null; then exec kitty --config "$1" -o "selection_background=$2" -o "selection_foreground=$3"; fi\n' +
                'for terminal in xdg-terminal-exec foot konsole gnome-terminal alacritty xterm; do\n' +
                '    if command -v "$terminal" >/dev/null; then exec "$terminal"; fi\n' +
                'done\n' +
                'if command -v notify-send >/dev/null; then notify-send -- "$4" "$5"; fi',
                "tahow-terminal", decodeURIComponent(Qt.resolvedUrl(dark ? "kitty/dark.conf" : "kitty/light.conf").toString().replace(/^file:\/\//, "")),
                Tahow.Theme.alpha(tones.highlight, 1).toString(), tones.highlightedText.toString(), Tahow.I18n.tr("Terminal"),
                Tahow.I18n.tr("No terminal emulator found")]);
            break;
        }
    }

    function openInternalFiles() {
        files.active = true;
        files.item?.requestActivate();
    }

    Process {
        id: openHome
        command: ["setsid", "-f", "-w", "sh", decodeURIComponent(Qt.resolvedUrl("../bin/open-files.sh").toString().replace(/^file:\/\//, "")),
            Quickshell.env("HOME"), Tahow.Config.dir + "/desktop-profile"]
        onExited: code => { if (code !== 0) root.openInternalFiles(); }
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
