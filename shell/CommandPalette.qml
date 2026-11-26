import QtQuick
import QtQml.XmlListModel
import Quickshell
import Quickshell.Io
import "lib/catalog.js" as Catalog
import "lib/spotlight-query.js" as Query

Scope {
    id: root
    property bool openRequested: false
    onOpenRequestedChanged: if (Host.adapter) Host.adapter.paletteState(openRequested, monitor)
    readonly property bool shown: openRequested || closing.running
    property string monitor: ""
    property string query: ""
    property string section: "all"
    property string category: "search"
    readonly property bool appsMode: category === "apps"
    property var actionHandler: null
    property var historyProvider: null
    readonly property bool wantsClipboardHistory: openRequested && category === "clipboard"
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
        { id: "tahow-files", name: I18n.tr("Files"), icon: "folder", glyph: "folder", categories: ["Utility"], tahowApp: "files" },
        { id: "tahow-calendar", name: I18n.tr("Calendar"), icon: "office-calendar", glyph: "timer", categories: ["Office"], tahowApp: "calendar" },
        { id: "tahow-terminal", name: I18n.tr("Terminal"), icon: "utilities-terminal", glyph: "monitor", categories: ["Utility"], tahowApp: "terminal" }
    ]
    readonly property var results: Catalog.results(builtinApps.concat(Array.from(DesktopEntries.applications.values)), query, section,
        Catalog.strings(shared.hiddenApps), Catalog.strings(shared.pinnedApps))
    readonly property var actionResults: actionHandler ? SpotlightActions.search(query) : []
    readonly property var quickKeyResults: actionHandler ? SpotlightActions.search(query, true) : []
    readonly property var recentEntries: {
        if (recent.status !== XmlListModel.Ready) return [];
        const entries = [];
        for (let i = 0; i < recent.count; i++) {
            const index = recent.index(i, 0);
            // XmlListModel numbers roles in declaration order starting at UserRole.
            entries.push({
                href: recent.data(index, Qt.UserRole),
                visited: recent.data(index, Qt.UserRole + 1),
                modified: recent.data(index, Qt.UserRole + 2)
            });
        }
        return entries;
    }
    readonly property var recentResults: Catalog.recentFiles(recentEntries, query)
    readonly property var searchResults: {
        if (!query.trim()) return results.slice(0, 6);
        const browser = Query.browserQuery(query);
        const web = browser ? {
            name: I18n.tr(browser.direct ? "Open website" : "Search the web"),
            comment: browser.direct ? browser.url : query.trim().replace(/^\?\s*/, ""),
            glyph: "search",
            webUrl: browser.url
        } : null;
        if (browser?.forced || browser?.direct) return [web];

        const value = Query.calculate(query);
        if (value !== null) return [{
            name: value.toLocaleString(I18n.locale, "g", 15),
            comment: I18n.tr("Copy calculation result"),
            glyph: "calculate",
            calculation: String(value)
        }];
        const local = Catalog.results(results.concat(recentResults, actionResults.filter(entry => !quickKeyResults.includes(entry))),
            query, "all", [], Catalog.strings(shared.pinnedApps));
        return quickKeyResults.concat(local, web ? [web] : []);
    }
    readonly property var clipboardResults: wantsClipboardHistory && historyProvider?.historyAllowed
        ? historyProvider.entries.filter(entry => Catalog.normalize(entry.preview).includes(Catalog.normalize(query).trim()))
            .map(entry => ({
                name: entry.imageFormat ? I18n.tr("Image") : entry.preview,
                glyph: "content_paste",
                clipboardId: entry.id
            }))
        : []
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
        category = applications === true ? "apps" : "search";
        selected = 0; openRequested = true;
    }
    function hide() {
        if (!openRequested) return;
        if (category === "clipboard") query = "";
        openRequested = false;
        closing.restart();
    }
    function toggle(mon) { openRequested ? hide() : show(mon); }
    function launch(entry) {
        if (!entry) return;
        if (entry.clipboardId) {
            historyProvider?.restoreHistory(entry.clipboardId, true);
            return;
        }
        hide();
        if (entry.actionId) {
            if (actionHandler) actionHandler(entry.actionId);
        } else if (entry.calculation !== undefined) Quickshell.execDetached(["wl-copy", "--", entry.calculation]);
        else if (entry.webUrl || entry.fileUrl) Qt.openUrlExternally(entry.webUrl || entry.fileUrl);
        else if (entry.tahowApp) Host.openDesktopAppRequested(entry.tahowApp);
        else Host.launch(entry);
    }
    function stateDump() { return { backdropCount: Object.keys(Host.backdrops).length, open: openRequested, query: wantsClipboardHistory ? "" : query, section: section, category: category, mode: appsMode ? "applications" : "search", selected: selected, resultCount: results.length, glass: glass, dark: dark, layout: sheetLoader.item ? sheetLoader.item.stateDump() : null }; }
    XmlListModel {
        id: recent
        source: root.openRequested && (root.category === "files" || root.category === "search") ? Qt.resolvedUrl(
            "file://" + (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/recently-used.xbel"
        ) : ""
        query: "/xbel/bookmark"
        XmlListModelRole { name: "href"; attributeName: "href" }
        XmlListModelRole { name: "visited"; attributeName: "visited" }
        XmlListModelRole { name: "modified"; attributeName: "modified" }
    }
    Timer { id: closing; interval: root.reduced ? 1 : Config.palette.mediumDuration }
    LazyLoader {
        id: sheetLoader
        active: root.shown && root.output !== null
        Sheet { launcher: root; screen: root.output }
    }
}
