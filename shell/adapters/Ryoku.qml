import QtQuick
import Quickshell
import shell.services as Shell
import Ryoku.Ui.Singletons as Ryoku
import Ryoku.Ui.Singletons
import ".."
QtObject {
    id: root
    readonly property string language: Ryoku.I18n.lang
    property var grab: null
    readonly property bool focusGrabAvailable: grab !== null && grab.available
    readonly property bool grabActive: Host.windows.some(w => w.explicitOpen)
    property string lastFocusedId: ""
    readonly property string focusedId: Wm.focusedWindow ? String(Wm.focusedWindow.id || "") : ""
    onFocusedIdChanged: {
        if (!focusedId || focusedId === lastFocusedId) return;
        const previous = lastFocusedId; lastFocusedId = focusedId;
        if (Host.captureCount > 0) return;
        if (previous) Hub.dismiss();
        Host.backgroundChanged();
    }
    onGrabActiveChanged: if (grab) grab.active = grabActive
    property Connections windowList: Connections { target: Host; function onWindowsChanged() { if (root.grab) root.grab.windows = Host.windows; } }
    function buildGrab() {
        if (!Wm.caps.focusGrab || grab) return;
        const path = (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell/shell/components/FocusGrab.qml";
        const component = Qt.createComponent("file://" + path);
        if (component.status !== Component.Ready) return;
        grab = component.createObject(root,{windows: Host.windows,active: grabActive});
        if (grab) grab.cleared.connect(() => { if (Host.captureCount === 0 && root.grabActive) Hub.dismiss(); });
    }
    readonly property var notifications: Shell.Notifs.tracked
    function removePopup(n) { Shell.Notifs.removePopup(n); }
    readonly property string focusedOutput: Wm.focusedOutput
    readonly property int workspace: Wm.focusedWorkspace ? Number(Wm.focusedWorkspace.id) : 1
    readonly property var occupied: (Wm.workspaces || []).map(w => Number(w.id))
    function fullscreen(name) { return Wm.outputHasFullscreen(name); }
    function paletteState(open, mon) { if (!open) Shell.ShellState.closeSurface("tahoe-palette-state", mon); }
    function launch(entry) { AppLaunch.run(entry, null); }
    function session(action) { Shell.SessionActions.run(action); }
    property Connections surfaces: Connections {
        target: Shell.ShellState
        function onSurfaceRequested(id, mon, context) {
            const base = String(id).split("#")[0];
            if (base === "tahoe-palette") Hub.openLauncher(String(mon || ""));
            if (base === "settings") Hub.openSettings();
        }
        function onSurfaceClosed(id, mon) { if (id === "tahoe-palette") Hub.closePalette(); if (String(id).split("#")[0] === "settings") Hub.settingsOpen = false; }
    }
    Component.onCompleted: { Host.adapter = root; buildGrab(); ReloadCover.enabled; }
    Component.onDestruction: if (Host.adapter === root) Host.adapter = null
}
