import QtQuick
import Quickshell
import Quickshell.Io
import "apps" as Apps

// Standalone palette runtime. Loaded by the launcher companion from the
// installed Tahow shell view when the Tahow subshell is not the active
// barStyle, so the palette works under any bar. Imports only the lightweight
// core (Config/Theme/Host) plus CommandPalette; the heavy Hub is never pulled.
Scope {
    id: root
    readonly property bool shown: commandPalette.shown
    property string monitor: ""
    function show(mon) { if (Config.s.paletteEnabled) commandPalette.show(mon); }
    function hide() { commandPalette.hide(); }
    function toggle(mon) { if (Config.s.paletteEnabled) commandPalette.toggle(mon); }
    Loader { source: "adapters/RyokuLite.qml" }
    CommandPalette { id: commandPalette }
    Apps.DesktopApps { id: desktopApps }

    function openDesktopApp(app) {
        desktopApps.open(app);
    }
    Connections {
        target: Host
        function onOpenDesktopAppRequested(app) {
            root.openDesktopApp(app);
        }
        function onOpenSettingsRequested() { Host.openSettings(); }
    }
    IpcHandler {
        target: "tahoe"
        function launcher(): void { root.toggle(""); }
        function openLauncher(mon: string): void { root.show(mon); }
        function openApplications(mon: string): void { if (Config.s.paletteEnabled) commandPalette.show(mon, true); }
        function openApp(app: string): void { root.openDesktopApp(app); }
        function files(): void { root.openDesktopApp("files"); }
        function closeLauncher(): void { root.hide(); }
        function state(): string { return JSON.stringify(commandPalette.stateDump()); }
    }
}
