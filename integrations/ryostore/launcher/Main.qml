import QtQuick
import Quickshell
import Quickshell.Io
import shell.services as Shell

// Launcher companion bridge. Works under ANY barStyle:
//  - Tahow subshell active  -> hand the palette to it (preserved surface ID).
//  - otherwise              -> load the standalone PaletteRuntime from the
//                              installed Tahow shell view and open it directly.
// The palette no longer requires the Tahow subshell to be the active bar.
Scope {
    id: root
    property bool shown: false
    property string monitor: ""
    readonly property bool subshellActive: Shell.Config.barStyle === "tahoe-shell"
    readonly property string storeRoot: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ryoku/store"
    property string runtimeSource: ""
    FileView {
        id: barstyles
        path: root.storeRoot + "/barstyles.json"
        watchChanges: true; blockLoading: true; printErrors: false
        onFileChanged: reload()
        onLoaded: root.resolveRuntime()
        onLoadFailed: root.runtimeSource = ""
    }
    function resolveRuntime() {
        try {
            const rows = JSON.parse(barstyles.text());
            const row = Array.isArray(rows) ? rows.find(r => r && r.id === "tahoe-shell") : null;
            runtimeSource = row && row.view ? "file://" + storeRoot + "/" + row.view + "/PaletteRuntime.qml" : "";
        } catch (e) { runtimeSource = ""; }
    }
    Loader {
        id: runtime
        active: !root.subshellActive && root.runtimeSource !== ""
        source: root.runtimeSource
    }
    function show(mon) {
        monitor = mon || "";
        if (subshellActive) {
            shown = true;
            Shell.ShellState.requestSurface("tahoe-palette", monitor, {});
            return;
        }
        if (runtime.item) {
            shown = true;
            runtime.item.show(monitor);
        } else {
            shown = false;
            console.warn("Tahow Palette needs the Tahow shell (tahoe-shell) installed. Install it via Ryostore, then retry.");
        }
    }
    onSubshellActiveChanged: if (shown) hide()
    function hide() {
        shown = false;
        if (subshellActive) Shell.ShellState.closeSurface("tahoe-palette", monitor);
        else if (runtime.item) runtime.item.hide();
    }
    function toggle(mon) { shown ? hide() : show(mon); }
    Connections {
        target: Shell.ShellState
        function onSurfaceClosed(id, mon) { if (id === "tahoe-palette-state") root.shown = false; }
    }
    Connections {
        target: runtime.item
        function onShownChanged() { root.shown = runtime.item.shown; }
    }
}