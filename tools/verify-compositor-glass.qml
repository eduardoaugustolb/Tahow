import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./ui" as Tahow
ShellRoot {
    id: root
    property int phase: 0
    property int stableFrames: 0
    property bool waiting: false
    function fail(message) { console.error("NATIVE_GLASS_FAILED: " + message); Qt.exit(1); }
    // A real application window below the overlay, not a wallpaper texture.
    Window {
        id: background
        visible: true; width: 1000; height: 650; color: "#15151c"
        title: "Tahow synthetic moving application"
        Row {
            x: root.phase === 1 ? 35 : 0
            Repeater { model: 32; Rectangle { required property int index; width: 80; height: background.height; color: index % 2 ? "#e84263" : "#35d68a" } }
        }
    }
    PanelWindow {
        id: overlay
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"; mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "tahow-live-test"
        Tahow.CompositorGlass { id: glass; x: 180; y: 80; width: 300; height: 180; radius: 40; target: "tahow-live-test" }
        Rectangle { x: glass.x; y: glass.y; width: glass.width; height: glass.height; radius: glass.radius; color: "#0cffffff"; border.color: "#66ffffff"; border.width: 1 }
        Text { x: 200; y: 140; text: "COMPOSITOR LIVE GLASS"; color: "white"; font.pixelSize: 18 }
    }
    Socket {
        id: stats
        path: glass.socketPath; connected: true
        parser: SplitParser { onRead: line => {
            const data = JSON.parse(line);
            if (data.op !== "stats") return;
            if (root.phase === 2) root.stableFrames = data.frames;
            if (root.phase === 3) {
                if (data.frames - root.stableFrames > 2) root.fail("static scene kept rendering " + (data.frames - root.stableFrames) + " frames");
                console.log("NATIVE_GLASS_OK idleFrames=" + (data.frames-root.stableFrames));
                Qt.quit();
            }
        } }
    }
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: {
            if (!glass.ready) { root.fail("native provider never presented the layer"); return; }
            root.phase++;
            if (root.phase === 1) console.log("NATIVE_GLASS_MOVED");
            if (root.phase === 2 || root.phase === 3) { stats.write(JSON.stringify({op:"stats"}) + "\n"); stats.flush(); }
        }
    }
    Timer { interval: 7000; running: true; onTriggered: root.fail("timeout") }
}
