import QtQuick
import Quickshell
import Quickshell.Io
import "lib/catalog.js" as Catalog
import "lib/material.js" as Material

Scope {
    id: root
    property bool openRequested: false
    onOpenRequestedChanged: if (Host.adapter) Host.adapter.paletteState(openRequested, monitor)
    readonly property bool shown: openRequested || closing.running
    property string monitor: ""
    property string query: ""
    property string section: "all"
    property int selected: 0
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property var shared: Config.palette
    readonly property var island: Config.palette
    readonly property var preferences: ({ opacity: Config.palette.glassOpacity, appearance: Config.palette.appearance, material: Config.palette.style === "black" ? "solid" : "glass", rim: Config.palette.glassRim })
    readonly property int columns: Math.round(Catalog.number(shared.columns, 7, 3, 16))
    readonly property int tileWidth: Math.round(Catalog.number(shared.matWidth, 82, 64, 180))
    readonly property real glassOpacity: Material.opacity(preferences.opacity)
    readonly property real frost: Catalog.number(shared.frost, 12, 0, 30)
    readonly property bool glass: preferences.material !== "solid" &&
        (preferences.material !== "island" || island.style !== "black")
    readonly property bool dark: !glass || preferences.appearance === "dark" ||
        (preferences.appearance !== "light" && (island.appearance === "dark" ||
            (island.appearance !== "light" && DesktopTheme.dark)))
    readonly property color ink: dark ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0.12, 0.10, 0.09, 0.94)
    readonly property color tint: glass ? Theme.materialTint(Config.palette, dark) : "#000000"
    readonly property string fontFamily: typeof island.font === "string" && island.font !== "auto" ? island.font : "sans-serif"
    // Same spring presets as Dynamic Island Theme.qml and its split bubbles.
    readonly property bool reduced: island.motion === "reduced"
    readonly property real spring: ({ gentle: 3.0, balanced: 3.6, bouncy: 4.2, reduced: 7 })[island.motion] || 3.6
    readonly property real damping: ({ gentle: 0.42, balanced: 0.30, bouncy: 0.21, reduced: 1.0 })[island.motion] || 0.30
    readonly property var results: Catalog.results(DesktopEntries.applications.values, query, section,
        Catalog.strings(shared.hiddenApps), Catalog.strings(shared.pinnedApps))
    readonly property var output: {
        const wanted = monitor || Host.focusedOutput;
        for (const s of Quickshell.screens) if (s.name === wanted) return s;
        return Quickshell.screens.length ? Quickshell.screens[0] : null;
    }
    onResultsChanged: selected = Math.max(0, Math.min(selected, results.length - 1))
    function parse(text) {
        try { const value = JSON.parse(text); return value && typeof value === "object" && !Array.isArray(value) ? value : {}; }
        catch (error) { return {}; }
    }
    function save(key, value) { const keys = {opacity:"glassOpacity",material:"style",rim:"glassRim"}; Config.set("palette", keys[key] || key, key === "material" ? (value === "solid" ? "black" : "glass") : value); }
    function show(mon) {
        closing.stop(); monitor = mon || ""; query = ""; section = "all"; selected = 0; openRequested = true;
    }
    function hide() { if (openRequested) { openRequested = false; closing.restart(); } }
    function toggle(mon) { openRequested ? hide() : show(mon); }
    function move(delta) { selected = Math.max(0, Math.min(results.length - 1, selected + delta)); }
    function launch(entry) { if (entry) { hide(); Host.launch(entry); } }
    function stateDump() { return { backdropCount: Object.keys(Host.backdrops).length, open: openRequested, query: query, section: section, selected: selected, resultCount: results.length, glass: glass, dark: dark, layout: sheetLoader.item ? sheetLoader.item.stateDump() : null }; }
    Timer { id: closing; interval: root.reduced ? 1 : Config.palette.mediumDuration }
    LazyLoader {
        id: sheetLoader
        active: root.shown && root.output !== null
        Sheet { launcher: root; screen: root.output }
    }
}
