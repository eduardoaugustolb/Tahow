pragma Singleton
import QtQuick
import Quickshell
Singleton {
    signal prepareRequested(string screen, string kind, int value)
    signal prepared(string screen, string kind, int value)
    signal preparationCancelled()
    function prepare(screen,kind,value) { prepareRequested(screen,kind,value); }
    property int captureCount: 0
    function beginCapture() { captureCount++; }
    function endCapture() { captureCount = Math.max(0,captureCount-1); }
    property var backdrops: ({})
    function backdrop(name, texture) { const next = Object.assign({}, backdrops); if (texture) next[name] = texture; else delete next[name]; backdrops = next; }
    property var windows: []
    readonly property bool canGrab: adapter && adapter.focusGrabAvailable
    signal backgroundChanged()
    function registerWindow(window) { windows = windows.concat([window]); }
    function unregisterWindow(window) { windows = windows.filter(w => w !== window); }
    property var adapter: null
    readonly property string focusedOutput: adapter ? adapter.focusedOutput : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
    readonly property int workspace: adapter ? adapter.workspace : 1
    readonly property var occupied: adapter ? adapter.occupied : []
    readonly property var notifications: adapter ? adapter.notifications : []
    readonly property bool ownsNotifications: !adapter
    function fullscreen(name) { return adapter ? adapter.fullscreen(name) : false; }
    function launch(entry) { if (adapter) adapter.launch(entry); else entry.execute(); }
}
