import QtQuick
import Quickshell
import "../shell" as Tahow

ShellRoot {
    id: root
    property int stage: 0
    function check(condition, message) { if (!condition) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const result = find(child, name); if (result) return result; }
        return null;
    }
    FloatingWindow {
        id: window
        visible: true; implicitWidth: 610; implicitHeight: 1300
        Tahow.GlassSettings {
            id: controls
            width: 590; x: 10; y: 10
            paper: "#242426"; ink: "#f5f5f7"; secondary: "#a5a5ab"; group: "#303033"; accent: "#86bfff"
        }
    }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            if (!Tahow.Config.probesDone) return;
            try {
                const slider = root.find(controls, controls.lockField ? "glass-slider-lockDispersion" : "glass-slider-dispersion");
                root.check(slider !== null, "Missing RGB slider");
                if (root.stage === 0) {
                    slider.value = 0.11; slider.moved();
                    root.check(Tahow.Config.value("general", "dispersion") === 0.11, "General slider did not save");
                    root.check(Tahow.Config.value("island", "dispersion") === 0.04, "General replaced a component override");
                    controls.componentIndex = 2;
                } else if (root.stage === 1) {
                    slider.value = 0.14; slider.moved();
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.14, "Palette slider did not save");
                } else if (root.stage === 2) {
                    root.find(controls, "glass-value-dispersion").text = "0.125";
                } else if (root.stage === 3) {
                    const numeric = root.find(controls, "glass-value-dispersion");
                    numeric.editingFinished();
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.125, "Exact numeric edit did not save: " + numeric.acceptableInput + ", " + numeric.text + ", " + Tahow.Config.value("palette", "dispersion"));
                    controls.resetOverrides();
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.11, "Reset did not inherit General");
                    root.check(Tahow.Config.value("palette", "columns") === 8, "Glass reset removed unrelated preferences");
                    controls.componentIndex = 3;
                } else if (root.stage === 4) {
                    slider.value = 0.17; slider.moved();
                    root.check(Tahow.Config.value("lockscreen", "lockDispersion") === 0.17, "Lock field slider did not save");
                    root.check(Tahow.Config.value("general", "dispersion") === 0.11, "Lock field modified general optics");
                } else {
                    console.log("GLASS_SETTINGS_OK");
                    Qt.quit();
                }
                root.stage++;
            } catch (error) { console.error("GLASS_SETTINGS_FAILED: " + error.message); Qt.quit(); }
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("GLASS_SETTINGS_FAILED: timed out"); Qt.quit(); } }
}
