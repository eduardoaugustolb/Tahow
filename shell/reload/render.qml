import QtQuick
import QtQuick.Window
import Quickshell

ShellRoot {
    Window {
        id: window
        width: 1920; height: 1080; visible: true
        property int frame: 0
        property bool saving: false
        property int warmup: 0
        Welcome { id: scene; anchors.fill: parent; wallpaper: Quickshell.env("TAHOW_COVER_WALLPAPER") || Qt.resolvedUrl("assets/tahow-glass-orbit.png"); phase: window.frame / 96 }
        Timer {
            interval: 25; repeat: true; running: true
            onTriggered: {
                if (++window.warmup < 8) return;
                if (window.saving) return;
                window.saving = true;
                scene.grabToImage(result => {
                    const name = Quickshell.env("TAHOW_COVER_FRAMES") + "/" + String(window.frame).padStart(4, "0") + ".png";
                    if (!result.saveToFile(name)) { console.error("Failed to save " + name); Qt.quit(); return; }
                    window.frame++;
                    if (window.frame >= 96) Qt.quit();
                    window.saving = false;
                });
            }
        }
    }
}
