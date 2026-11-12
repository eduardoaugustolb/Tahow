import QtQuick
import Quickshell
import shell.services as Shell
Scope {
    id: root
    property bool shown: false
    property string monitor: ""
    readonly property bool subshellActive: Shell.Config.barStyle === "tahoe-shell"
    function show(mon) {
        if (!subshellActive) {
            shown = false;
            console.warn("Tahow Palette requires the Tahow subshell (tahoe-shell) to be active. Select it in Ryoku Hub > Subshells.");
            return;
        }
        monitor = mon || ""; shown = true;
        Shell.ShellState.requestSurface("tahoe-palette", monitor, {});
    }
    onSubshellActiveChanged: if (!subshellActive && shown) hide()
    function hide() { shown = false; Shell.ShellState.closeSurface("tahoe-palette", monitor); }
    function toggle(mon) { shown ? hide() : show(mon); }
    Connections { target: Shell.ShellState
        function onSurfaceClosed(id, mon) { if (id === "tahoe-palette-state") root.shown = false; }
    }
}
