import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./ui" as Tahow
ShellRoot {
    id: root
    property bool changed: false
    PanelWindow {
        anchors {top:true;bottom:true;left:true;right:true}
        color: "#282828"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "tahow-damage-background"
        Rectangle {x:145;y:130;width:20;height:80;color:root.changed ? "#ff2222" : "#22ff22"}
    }
    PanelWindow {
        anchors {top:true;bottom:true;left:true;right:true}
        color: "transparent"; mask:Region{}
        exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.namespace:"tahow-live-test"
        Item {
            x:180;y:80;width:80;height:180;clip:true
            Tahow.CompositorGlass {id:glass;width:300;height:180;radius:40;bezel:40;thickness:48;ior:2;dispersion:0;frost:0;target:"tahow-live-test"}
        }
    }
    IpcHandler {target:"tahowNativeDamage";function change():void{root.changed=true;}}
    Timer {interval:100;repeat:true;running:true;onTriggered:if(glass.ready){stop();console.log("NATIVE_DAMAGE_READY");}}
    Timer {interval:15000;running:true;onTriggered:Qt.quit()}
}
