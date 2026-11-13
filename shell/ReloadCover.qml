pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    // Opt-in generation only; publication remains the host's responsibility.
    readonly property bool enabled: Config.s.reloadCoverFollowWallpaper
    readonly property string runtimePath: (Quickshell.env("PATH") || "/usr/local/bin:/usr/bin:/bin")
        + ":" + Quickshell.env("HOME") + "/.bun/bin"
        + ":" + (Quickshell.env("MISE_DATA_DIR") || Quickshell.env("HOME") + "/.local/share/mise") + "/installs/bun/latest/bin"
    readonly property string outputPath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/tahow-shell/reload-cover.mp4"
    Process {
        id: worker
        running: ReloadCover.enabled
        command: ["env", "PATH=" + ReloadCover.runtimePath, "bun", decodeURIComponent(Qt.resolvedUrl("bin/reload-cover.ts").toString().replace(/^file:\/\//, "")), "--watch", ReloadCover.outputPath]
    }
}
