import QtQuick
import Quickshell
import Quickshell.Io
import "lib/catalog.js" as Catalog

Scope {
    id: root
    property bool openRequested: false
    onOpenRequestedChanged: if (Host.adapter) Host.adapter.paletteState(openRequested, monitor)
    readonly property bool shown: openRequested || closing.running
    property string monitor: ""
    property string query: ""
    property string section: "all"
    property bool appsMode: false
    property int selected: 0
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property var shared: Config.palette
    readonly property var island: Config.palette
    readonly property var preferences: ({ opacity: Config.palette.glassOpacity, appearance: Config.palette.appearance, material: Config.palette.style === "black" ? "solid" : "glass", rim: Config.palette.glassRim })
    readonly property int columns: Math.round(Catalog.number(shared.columns, 7, 3, 16))
    readonly property int tileWidth: Math.round(Catalog.number(shared.matWidth, 82, 64, 180))
    readonly property bool glass: preferences.material !== "solid" &&
        (preferences.material !== "island" || island.style !== "black")
    readonly property bool dark: preferences.appearance === "dark" ||
        (preferences.appearance !== "light" && Theme.autoDark)
    readonly property color ink: dark ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0.12, 0.10, 0.09, 0.94)
    readonly property color tint: glass ? Theme.materialTint(Config.palette, dark) : (dark ? "#1a1c22" : "#f4f5f8")
    readonly property string fontFamily: typeof island.font === "string" && island.font !== "auto" ? island.font : "sans-serif"
    // Same spring presets as Dynamic Island Theme.qml and its split bubbles.
    readonly property bool reduced: island.motion === "reduced"
    readonly property real spring: ({ gentle: 3.0, balanced: 3.6, bouncy: 4.2, reduced: 7 })[island.motion] || 3.6
    readonly property real damping: ({ gentle: 0.42, balanced: 0.30, bouncy: 0.21, reduced: 1.0 })[island.motion] || 0.30
    readonly property var builtinApps: [
        { id: "tahow-files", name: I18n.tr("Files"), icon: "system-file-manager", glyph: "home", categories: ["Utility"], tahowApp: "files" },
        { id: "tahow-calendar", name: I18n.tr("Calendar"), icon: "office-calendar", glyph: "timer", categories: ["Office"], tahowApp: "calendar" },
        { id: "tahow-terminal", name: I18n.tr("Terminal"), icon: "utilities-terminal", glyph: "monitor", categories: ["Utility"], tahowApp: "terminal" }
    ]
    readonly property var results: Catalog.results(builtinApps.concat(Array.from(DesktopEntries.applications.values)), query, section,
        Catalog.strings(shared.hiddenApps), Catalog.strings(shared.pinnedApps))
    readonly property var output: {
        const wanted = monitor || Host.focusedOutput;
        for (const s of Quickshell.screens) if (s.name === wanted) return s;
        return Quickshell.screens.length ? Quickshell.screens[0] : null;
    }
    function parse(text) {
        try { const value = JSON.parse(text); return value && typeof value === "object" && !Array.isArray(value) ? value : {}; }
        catch (error) { return {}; }
    }
    function save(key, value) { const keys = {opacity:"glassOpacity",material:"style",rim:"glassRim"}; Config.set("palette", keys[key] || key, key === "material" ? (value === "solid" ? "black" : "glass") : value); }
    function show(mon, applications) {
        closing.stop(); monitor = mon || ""; query = ""; section = "all";
        appsMode = applications === true; selected = 0; openRequested = true;
    }
    function hide() { if (openRequested) { openRequested = false; closing.restart(); } }
    function toggle(mon) { openRequested ? hide() : show(mon); }
    function launch(entry) {
        if (!entry) return;
        hide();
        if (entry.tahowApp) Host.openDesktopAppRequested(entry.tahowApp);
        else Host.launch(entry);
    }
    function stateDump() { return { backdropCount: Object.keys(Host.backdrops).length, open: openRequested, query: query, section: section, mode: appsMode ? "applications" : "search", selected: selected, resultCount: results.length, glass: glass, dark: dark, layout: sheetLoader.item ? sheetLoader.item.stateDump() : null }; }
    Timer { id: closing; interval: root.reduced ? 1 : Config.palette.mediumDuration }
    LazyLoader {
        id: sheetLoader
        active: root.shown && root.output !== null
        Sheet { launcher: root; screen: root.output }
    }
}
