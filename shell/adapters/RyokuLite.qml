import QtQuick
import Quickshell
import shell.services as Shell
import Ryoku.Ui.Singletons as Ryoku
import Ryoku.Ui.Singletons
import ".."

// Lightweight host adapter for standalone companions (the palette). Reads the
// desktop's launch/language/focus services without FocusGrab, reload-cover
// probes or desktop capture, so it never contends with the full shell owner.
QtObject {
    id: root
    readonly property string language: Ryoku.I18n.lang
    readonly property bool desktopCaptureReady: true
    readonly property bool desktopCaptureAllowed: false
    readonly property bool focusGrabAvailable: false
    readonly property string focusedOutput: Wm.focusedOutput
    readonly property int workspace: Wm.focusedWorkspace ? Number(Wm.focusedWorkspace.id) : 1
    readonly property var occupied: (Wm.workspaces || []).map(w => Number(w.id))
    function fullscreen(name) { return Wm.outputHasFullscreen(name); }
    readonly property var notifications: Shell.Notifs.tracked
    function removePopup(n) { Shell.Notifs.removePopup(n); }
    function paletteState(open, mon) { if (!open) Shell.ShellState.closeSurface("tahoe-palette-state", mon); }
    function launch(entry) { Shell.AppLaunch.run(entry, null); }
    function session(action) { Shell.SessionActions.run(action); }
    function openSettings() { Shell.ShellState.requestSurface("tahoe-settings", "", {}); }
    Component.onCompleted: Host.adapter = root
    Component.onDestruction: if (Host.adapter === root) Host.adapter = null
}