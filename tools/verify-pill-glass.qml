import QtQuick
import Quickshell
import "./shell" as Tahow

// Isolated state and fake notifications. No Runtime/Lockscreen or authentication.
ShellRoot {
    id: root
    property bool expectCapture: Quickshell.env("TAHOW_CAPTURE_TEST") === "1"
    property int phase: -1
    property int samples: 0
    property var texture: null
    Component.onDestruction: Tahow.Host.adapter = null
    readonly property var modes: ["idle", "idlePeek", "media", "mediaPeek", "notif", "osd", "device", "workspace", "timer", "timerPeek", "recording", "recordingPeek", "expanded", "idle"]
    QtObject {
        id: adapter
        property string focusedOutput: Quickshell.screens[0].name
        property int workspace: 1
        property var occupied: [1]
        property bool focusGrabAvailable: false
        property var notifications: []
        function removePopup(n) {}
        function fullscreen(name) { return false; }
    }
    Tahow.IslandWindow { id: win; modelData: Quickshell.screens[0] }
    Component.onCompleted: {
        Tahow.Host.adapter = adapter;
        Tahow.Hub.armed = false;
        adapter.notifications = [{id: 9901, appName: "Tahow", summary: "Glass transition", body: "A prepared surface stays visible through every pill state.", appIcon: "dialog-information", desktopEntry: "", image: "", actions: [], urgency: 1, hints: {}, transient: false}];
    }
    function check(condition, message) {
        if (!condition) { console.error("PILL_GLASS_FAILED: " + message); Qt.exit(1); }
    }
    Timer {
        interval: 16; repeat: true; running: root.phase >= 0
        onTriggered: {
            const s = win.layoutDump();
            root.check(s.presentationReady && !s.acquiringBackdrop, "unexpected acquisition during morph");
            root.check(s.islandOpacity === 1 && s.surfaceOpacity === 1, "visible surface faded out");
            root.check(Tahow.Host.captureCount === 0, "capture ownership leaked");
            root.check(Tahow.Host.backdrops[win.screenName] === root.texture, "texture replaced during morph");
            root.check(s.liquidReady === root.expectCapture, "liquid readiness changed during morph");
            root.check(!root.expectCapture || s.liquidMix >= 0.999, "prepared material faded out during morph");
            root.samples++;
        }
    }
    Timer {
        interval: 100; repeat: true; running: root.phase < 0
        onTriggered: {
            const s = win.layoutDump();
            if (!s.presentationReady || s.acquiringBackdrop) return;
            if (root.expectCapture && (!s.liquidReady || s.liquidMix < 0.999)) return;
            root.check(s.captureHasContent === root.expectCapture, "capture/fallback mismatch");
            root.texture = Tahow.Host.backdrops[win.screenName];
            root.phase = 0;
            Tahow.Hub.event = root.modes[0];
            advance.start();
        }
    }
    Timer {
        id: advance
        interval: 500; repeat: true
        onTriggered: {
            root.check(win.layoutDump().mode === root.modes[root.phase], "incorrect mode");
            if (root.expectCapture && [1, 3, 4].indexOf(root.phase) >= 0) {
                const path = "/tmp/tahow-pill-" + root.modes[root.phase] + ".png";
                const pill = win.contentItem.children.find(item => item.objectName === "tahow-island");
                root.check(!!pill, "island not found for visual verification");
                pill.grabToImage(result => result.saveToFile(path));
            }
            root.phase++;
            if (root.phase === root.modes.length) {
                stop();
                console.log("PILL_GLASS_OK capture=" + root.expectCapture + " modes=" + root.modes.length + " samples=" + root.samples);
                Tahow.Host.adapter = null;
                Qt.quit();
            } else Tahow.Hub.event = root.modes[root.phase];
        }
    }
    Timer { interval: 13000; running: true; onTriggered: root.check(false, "timed out " + JSON.stringify(win.layoutDump())) }
}
