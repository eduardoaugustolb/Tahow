import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "i18n/paths.js" as Paths
import "i18n/material.js" as Material

Item {
    id: root
    function option(key) { const own = (islandSettings.adapter.overrides || {}).lockscreen || {}; return own[key] !== undefined ? own[key] : islandSettings.adapter[key]; }
    property var wallpaperPalette: ({})
    property var namedPalette: ({})
    property bool followWallpaper: true
    readonly property var palette: followWallpaper ? wallpaperPalette : namedPalette
    readonly property color systemBackground: palette.surface || palette.background || "#111418"
    readonly property color systemAccent: palette.primary || "#0a84ff"
    readonly property bool dark: option("style") === "black" || option("appearance") === "dark" || (option("appearance") !== "light" && (systemBackground.r + systemBackground.g + systemBackground.b < 1.5))
    readonly property color materialTint: option("style") === "black" ? "#000000" : Material.tint(dark, option("glassAccentTint"), accent)
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/ryoku/colors.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { try { root.wallpaperPalette = JSON.parse(text()); } catch (_) {} }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ryoku/theme.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { try { root.followWallpaper = JSON.parse(text()).followWallpaper !== false; } catch (_) {} }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ryoku/shell.json"
        watchChanges: true; printErrors: false; onFileChanged: reload()
        onLoaded: { try { root.namedPalette = JSON.parse(text()).themePalette || {}; } catch (_) {} }
    }
    readonly property string fontFamily: option("font") === "auto" ? "Inter" : option("font")
    // Read-only: follow the installed Dynamic Island motion preference.
    readonly property string motion: option("motion")
    readonly property bool use24h: option("use24h")
    readonly property int easing: option("easing")
    readonly property int fastDuration: option("fastDuration")
    readonly property int mediumDuration: option("mediumDuration")
    readonly property color accent: option("accentSource") === "custom" ? option("customAccent") : systemAccent
    readonly property var paths: ({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    })
    property bool canonicalReady: false
    property bool legacyReady: false
    readonly property string settingsPath: Paths.settingsPath(root.paths, root.canonicalReady, root.legacyReady)
    FileView {
        id: canonicalProbe
        path: Paths.canonicalSettingsPath(root.paths)
        blockLoading: true; printErrors: false
        onLoaded: root.canonicalReady = true
        onLoadFailed: root.canonicalReady = false
    }
    FileView {
        id: legacyProbe
        path: Paths.legacySettingsPath(root.paths)
        blockLoading: true; printErrors: false
        onLoaded: root.legacyReady = true
        onLoadFailed: root.legacyReady = false
    }
    FileView {
        id: islandSettings
        // The canonical ~/.config/tahow-shell/settings.json always wins. The
        // legacy ~/.config/tahoe-shell/settings.json is only read when the
        // canonical file does not exist yet.
        path: root.settingsPath
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: reload()
        JsonAdapter { property string style: "glass"; property bool glassAccentTint: true; property string appearance: "auto"; property string accentSource: "auto"; property real lockFooterScale: 1.12; property real lockRim: 0.22; property real lockTint: 0.035; property real lockThickness: 14; property real lockIor: 1.25; property real lockDispersion: 0.08; property real lockEnergy: 0.05; property real lockBezel: 6; property var overrides: ({}); property string font: "auto"; property string motion: "balanced"; property bool use24h: false; property int easing: 6; property int fastDuration: 180; property int mediumDuration: 300; property string customAccent: "#0a84ff" }
    }
    property string wallpaperUrl: ""
    readonly property int batteryLevel: UPower.displayDevice && UPower.displayDevice.isLaptopBattery ? Math.round(UPower.displayDevice.percentage * 100) : -1
    readonly property bool charging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging
    function applyWallpaper(line) {
        try {
            const frame = JSON.parse(line)
            const entry = (frame.outputs && frame.outputs[Screen.name || ""]) || frame.default
            if (entry && entry.path) wallpaperUrl = "file://" + entry.path + "?v=" + Number(entry.revision || 0)
        } catch (error) { console.warn("tahoe: invalid wallpaper frame", error) }
    }
    Socket {
        id: socket
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryogami.sock"
        parser: SplitParser { onRead: line => root.applyWallpaper(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) { write("subscribe wallpaper\n"); flush() }
            else retry.restart()
        }
        onError: { connected = false; retry.restart() }
    }
    Timer { id: retry; interval: 2000; onTriggered: if (!socket.connected) socket.connected = true }
}
