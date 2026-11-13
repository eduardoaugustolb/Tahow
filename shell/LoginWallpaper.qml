pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
Singleton {
    id: root
    property string status: ""
    property string pending: ""
    readonly property bool busy: upload.running || debounce.running
    // A systemd-launched shell may not inherit interactive mise/Bun paths.
    readonly property string runtimePath: (Quickshell.env("PATH") || "/usr/local/bin:/usr/bin:/bin")
        + ":" + Quickshell.env("HOME") + "/.bun/bin"
        + ":" + (Quickshell.env("MISE_DATA_DIR") || Quickshell.env("HOME") + "/.local/share/mise") + "/installs/bun/latest/bin"
    function publish(path) {
        if (!path) return;
        pending = path;
        debounce.restart();
    }
    function follow() {
        if (Config.s.loginFollowWallpaper) publish(DesktopTheme.wallpaper);
    }
    Component.onCompleted: follow()
    Connections {
        target: DesktopTheme
        function onWallpaperPublished(path) { if (Config.s.loginFollowWallpaper) root.publish(path); }
    }
    Connections {
        target: Config.s
        function onLoginFollowWallpaperChanged() {
            if (Config.s.loginFollowWallpaper) root.follow();
            else { root.pending = ""; debounce.stop(); }
        }
    }
    Timer {
        id: debounce; interval: 300
        onTriggered: {
            if (upload.running) return;
            upload.command = ["env", "PATH=" + root.runtimePath, "bun", decodeURIComponent(Qt.resolvedUrl("bin/login-wallpaper.ts").toString().replace(/^file:\/\//, "")), root.pending];
            root.pending = "";
            root.status = "Updating login wallpaper";
            upload.running = true;
        }
    }
    Process {
        id: upload
        onExited: (code, signal) => {
            root.status = code === 0 ? "Login wallpaper updated" : "Login wallpaper failed. Check the login integration setup.";
            if (root.pending) debounce.restart();
        }
    }
}
