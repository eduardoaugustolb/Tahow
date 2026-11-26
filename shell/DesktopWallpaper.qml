pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool busy: applyProcess.running
    property string status: ""
    property string requestedMode: "crop"
    property bool restoring: false

    function apply(image, mode, restore = false) {
        if (!image || busy) return;
        requestedMode = mode;
        restoring = restore;
        status = "Applying wallpaper…";
        const script = decodeURIComponent(Qt.resolvedUrl("bin/desktop-wallpaper.ts").toString().replace(/^file:\/\//, ""));
        applyProcess.command = ["env", "PATH=" + LoginWallpaper.runtimePath, "bun", script, image, mode];
        applyProcess.running = true;
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text.trim()) return;
                const path = JSON.parse(this.text);
                if (!root.restoring) Config.setValues("general", {desktopWallpaperPath: path, desktopWallpaperMode: root.requestedMode});
                DesktopTheme.wallpaper = path;
                DesktopTheme.wallpaperPublished(path);
                root.status = "Wallpaper applied";
            }
        }
        onExited: code => {
            if (code !== 0) root.status = "Could not apply wallpaper. Check that awww or swww is available.";
        }
    }
}
