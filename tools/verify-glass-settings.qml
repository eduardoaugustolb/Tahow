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
                    controls.save("screenCapture", true);
                    const optics = root.find(controls, "glass-preview-optics");
                    const veil = root.find(controls, "glass-preview-veil");
                    root.check(optics.tintAmount === 0 && veil.visible, "Preview applies tint more than once");
                    const rim = root.find(controls, "glass-slider-rimStrength");
                    rim.value = 0.12; rim.moved();
                    controls.save("glassRim", true);
                    root.check(Tahow.Config.value("general", "rimStrength") === 0.12 && optics.rim === 0.12, "Rim intensity did not reach preview");
                    controls.save("glassRim", false);
                    root.check(optics.rim === 0, "Rim toggle did not disable preview highlight");
                    controls.save("screenCapture", false);
                    root.check(!controls.opticalPreview, "Preview ignores capture being disabled");
                    controls.save("screenCapture", true);
                    controls.save("style", "black");
                    root.check(!controls.opticalPreview, "Black material still refracts");
                    controls.save("style", "prism");
                    root.check(optics.prism === 1 && controls.opticalPreview, "Prismatic material did not reach preview");
                    controls.save("style", "glass");
                    const shadow = root.find(controls, "glass-slider-innerShadow");
                    root.check(shadow !== null, "Missing inner shadow slider");
                    shadow.value = 0; shadow.moved();
                    root.check(Tahow.Config.value("general", "innerShadow") === 0, "Zero inner shadow did not save");
                    slider.value = 0.11; slider.moved();
                    root.check(Tahow.Config.value("general", "dispersion") === 0.11, "General slider did not save");
                    root.check(Tahow.Config.value("island", "dispersion") === 0.04, "General replaced a component override");
                    controls.componentIndex = 2;
                } else if (root.stage === 1) {
                    root.check(Tahow.Config.value("palette", "innerShadow") === 0, "Inner shadow did not inherit zero");
                    const shadow = root.find(controls, "glass-slider-innerShadow");
                    shadow.value = 0.65; shadow.moved();
                    root.check(Tahow.Config.value("palette", "innerShadow") === 0.65, "Component inner shadow did not save");
                    slider.value = 0.14; slider.moved();
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.14, "Palette slider did not save");
                } else if (root.stage === 2) {
                    root.find(controls, "glass-value-dispersion").text = "0.125";
                } else if (root.stage === 3) {
                    const numeric = root.find(controls, "glass-value-dispersion");
                    numeric.editingFinished();
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.125, "Exact numeric edit did not save: " + numeric.acceptableInput + ", " + numeric.text + ", " + Tahow.Config.value("palette", "dispersion"));
                    controls.resetOverrides();
                    root.check(Tahow.Config.value("palette", "innerShadow") === 0, "Inner shadow reset did not inherit General");
                    root.check(Tahow.Config.value("palette", "dispersion") === 0.11, "Reset did not inherit General");
                    root.check(Tahow.Config.value("palette", "columns") === 8, "Glass reset removed unrelated preferences");
                    controls.componentIndex = 3;
                } else if (root.stage === 4) {
                    const wallpaper = root.find(controls, "glass-preview-wallpaper");
                    root.check(wallpaper.status === Image.Ready, "Preview did not load the configured wallpaper");
                    const optics = root.find(controls, "glass-preview-lock-optics");
                    const veil = root.find(controls, "glass-preview-veil");
                    root.check(!veil.visible, "Lock tint is applied twice");
                    root.check(String(optics.fragmentShader).includes("lock/shaders/"), "Lock preview uses a different shader");
                    root.check(optics.tintAmount === controls.options.lockTint, "Lock preview ignores field tint");
                    controls.save("style", "prism");
                    root.check(optics.bezel === controls.options.lockBezel * 1.5 && optics.thickness === controls.options.lockThickness * 2
                        && optics.dispersion === Math.max(0.16, controls.options.lockDispersion * 2), "Lock preview ignores prismatic optics");
                    controls.save("style", "glass");
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
