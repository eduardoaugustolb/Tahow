import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./shell" as Tahow
ShellRoot {
    id: root
    property real shadow: 1
    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        color: "#c0c8d0"
        // A sharp boundary reveals refraction while the remaining backdrop is flat.
        Rectangle { x: 460; y: 0; width: 70; height: parent.height; color: "#264766" }
    }
    PanelWindow {
        id: overlay
        visible: !settings.visible
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "tahow-live-test"
        color: "transparent"; mask: Region {}
        Tahow.CompositorGlass {
            id: glass; x: 180; y: 100; width: 360; height: 200; radius: 40
            target: "tahow-live-test"; innerShadow: root.shadow
            bezel: 24; thickness: 32; ior: 1.69; dispersion: 0.135; frost: 6.5
        }
        // Ensure the owning surface has a nonempty committed buffer.
        Rectangle { x: 200; y: 190; width: 1; height: 1; color: "white" }
    }
    Tahow.SettingsWindow { id: settings; visible: false }
    IpcHandler {
        target: "tahowShadowTest"
        function shadow(value: real): void { root.shadow = value; }
        function showSettings(): void { settings.visible = true; }
        function state(): string { return JSON.stringify({ready:glass.ready,geometry:glass.geometry}); }
    }
    Timer { interval: 100; repeat: true; running: true; onTriggered: if(glass.ready) { console.log("INNER_SHADOW_READY"); stop(); } }
    Timer { interval: 20000; running: true; onTriggered: Qt.quit() }
}
