pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property string wallpaper: ""
    signal wallpaperPublished(string path)
    property var palette: ({})
    property var named: ({})
    property bool follow: true
    readonly property var selected: follow ? palette : named
    readonly property bool available: !!selected.primary
    readonly property color accent: selected.primary || "#0a84ff"
    readonly property color background: selected.surface || selected.background || "#111418"
    readonly property bool dark: (background.r + background.g + background.b) < 1.5
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    function object(text) { try { return JSON.parse(text); } catch (_) { return null; } }
    function refresh() { colors.reload(); theme.reload(); shell.reload(); }
    FileView {
        id: colors; path: root.cacheHome + "/ryoku/colors.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { const p = root.object(text()); if (p && p.primary) root.palette = p; }
    }
    FileView {
        id: theme; path: root.configHome + "/ryoku/theme.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { const p = root.object(text()); if (p) root.follow = p.followWallpaper !== false; }
    }
    FileView {
        id: shell; path: root.configHome + "/ryoku/shell.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { const p = root.object(text()); if (p && p.themePalette) root.named = p.themePalette; }
    }
    Loader {
        id: subscription
        active: true
        sourceComponent: Socket {
            path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryogami.sock"
            Component.onCompleted: connected = true
            onConnectionStateChanged: if (connected) { write("subscribe wallpaper\n"); flush(); } else subscription.active = false
            onError: subscription.active = false
            parser: SplitParser { onRead: line => {
                const frame = root.object(line);
                const entry = frame && ((frame.outputs && frame.outputs[Host.focusedOutput]) || frame.default);
                if (entry && entry.path) {
                    root.wallpaper = entry.path;
                    root.wallpaperPublished(entry.path);
                }
                root.refresh();
            } }
        }
    }
    Timer { interval: 2000; repeat: true; running: !subscription.active; onTriggered: subscription.active = true }
    IpcHandler { target: "tahoeTheme"; function refresh(): void { root.refresh(); } }
}
