import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    Window {
        id: window
        width: 1200; height: 440; visible: true
        property int frame: 0
        property bool saving: false
        property int warmup: 0
        readonly property int frameCount: Number(Quickshell.env("TAHOW_BANNER_COUNT") || 96)
        Banner { id: scene; anchors.fill: parent; phase: window.frame/96 }
        Timer {
            interval: 20; repeat: true; running: true
            onTriggered: {
                if (++window.warmup < 8 || window.saving) return;
                window.saving = true;
                scene.grabToImage(result => {
                    const path = Quickshell.env("TAHOW_BANNER_FRAMES")+"/"+String(window.frame).padStart(4,"0")+".png";
                    if (!result.saveToFile(path)) { console.error("Frame save failed"); Qt.quit(); return; }
                    if (++window.frame >= window.frameCount) Qt.quit();
                    window.saving = false;
                });
            }
        }
    }
}
