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
        visible: true; implicitWidth: 610; implicitHeight: 500
        Tahow.GlassSettings {
            id: controls
            width: 590; x: 10; y: 10
            paper: "#242426"; ink: "#f5f5f7"; secondary: "#a5a5ab"; group: "#303033"; accent: "#86bfff"
        }
    }
    Tahow.SettingsWindow { id: settings; page: 1 }
    Timer {
        interval: 180; running: true; repeat: true
        onTriggered: {
            if (!Tahow.Config.probesDone) return;
            try {
                const slider = root.find(controls, "glass-slider-strength");
                root.check(slider !== null, "Missing strength slider");
                if (root.stage === 0) {
                    Tahow.DesktopTheme.wallpaper = Tahow.Config.general.wallpaperPath;
                    if (Tahow.Theme.desktopWallAccent === "") return;
                    root.check(settings.currentPage.page === 1
                        && settings.visiblePages.map(entry => entry.page).join() === "7,8,11,12,4,0,24,6,1,2,3,10,9,23,5",
                        "Settings must provide direct sidebar links for all pages");
                    settings.page = 4;
                    root.check(!settings.ryokuSession && !settings.keys.includes("reloadCoverFollowWallpaper"),
                        "Standalone settings must hide the Ryoku reload cover option");
                    settings.page = 1;
                    settings.pageSearch = Tahow.I18n.tr("Spotlight");
                    root.check(settings.visiblePages.length === 1 && settings.visiblePages[0].page === 2,
                        "Searching for Spotlight must find its sidebar page");
                    Tahow.Config.set("general", "iconStyle", "tinted");
                    root.check(Tahow.Config.general.iconStyle === "tinted", "Icon style did not update");
                    settings.pageSearch = "";
                    Tahow.DesktopTheme.follow = false;
                    Tahow.DesktopTheme.named = {primary: "#007aff"};
                    Tahow.DesktopTheme.palette = {primary: "#33bd4b"};
                    Tahow.Config.set("general", "accentSource", "wallpaper");
                    root.check(Qt.colorEqual(settings.accent, "#808080"), "Settings did not use the gray wallpaper");
                    root.check(Qt.colorEqual(Tahow.Theme.rawAccent, "#808080"), "Island did not use the gray wallpaper");
                    root.check(Qt.colorEqual(Tahow.Theme.materialAccent(Tahow.Config.general, "#0a84ff", ""), "#33bd4b"),
                        "The desktop palette fallback was lost");
                    Tahow.Config.setValues("general", {accentSource: "custom", customAccent: "#96969a"});
                    Tahow.Config.setValues("island", {accentSource: "custom", customAccent: "#fa3d45"});
                    root.check(Qt.colorEqual(settings.accent, "#96969a"), "Settings ignored General custom accent");
                    root.check(Qt.colorEqual(Tahow.Theme.rawAccent, "#fa3d45"), "Island ignored its accent override");
                    root.check(Qt.colorEqual(Tahow.Theme.materialAccent(Tahow.Config.palette), "#96969a")
                        && Qt.colorEqual(Tahow.Theme.materialAccent(Tahow.Config.input), "#96969a")
                        && Qt.colorEqual(Tahow.Theme.materialAccent(Tahow.Config.lockscreen), "#96969a"), "Component accent leaked from the island");
                    slider.value = 50; slider.moved();
                    root.check(Tahow.Config.general.thickness === 30 && Tahow.Config.general.dispersion === 0.1
                        && Tahow.Config.general.ior === 1.55, "Strength did not update general optics");
                    root.check(Tahow.Config.island.dispersion === 0.04, "General replaced a component override");
                    const preset = root.find(controls, "glass-preset");
                    root.check(preset.currentIndex === -1, "Existing glass settings should read as Custom");
                    preset.activated(1);
                    root.check(Tahow.Config.general.glassOpacity === 0.55 && Tahow.Config.general.lockTint === 0.35
                        && Tahow.Config.general.glassAccentTint && Tahow.Config.island.dispersion === 0.04,
                        "General preset did not update tint or overwrote island optics");
                    controls.componentIndex = 2;
                } else if (root.stage === 1) {
                    root.check(slider.value === 50, "Palette did not inherit strength");
                    const preset = root.find(controls, "glass-preset");
                    root.check(preset.currentIndex === 1, "Palette did not inherit the General tint");
                    preset.activated(2);
                    root.check(Tahow.Config.palette.glassOpacity === 1 && Tahow.Config.general.glassOpacity === 0.55,
                        "Palette preset did not stay independent");
                    slider.value = 75; slider.moved();
                    root.check(Tahow.Config.palette.thickness === 45, "Palette strength did not save");
                    controls.resetOverrides();
                    root.check(Tahow.Config.palette.thickness === 30 && Tahow.Config.palette.columns === 8,
                        "Reset did not inherit General or removed unrelated preferences");
                    root.check(Tahow.Config.palette.glassOpacity === 0.55,
                        "Palette reset did not inherit the default tint");
                    controls.componentIndex = 3;
                } else if (root.stage === 2) {
                    const wallpaper = root.find(controls, "glass-preview-wallpaper");
                    root.check(wallpaper.status === Image.Ready, "Preview did not load the configured wallpaper");
                    const optics = root.find(controls, "glass-preview-lock-optics");
                    const preset = root.find(controls, "glass-preset");
                    preset.activated(0);
                    root.check(Tahow.Config.lockscreen.lockTint === 0.035
                        && Tahow.Config.general.lockTint === 0.35,
                        "Lock preset did not use the lock field tint independently");
                    slider.value = 80; slider.moved();
                    root.check(Math.abs(optics.thickness - 33.6) < 0.001 && Tahow.Config.general.thickness === 30,
                        "Lock strength did not affect the preview independently");
                    controls.save("style", "prism");
                } else if (root.stage === 3) {
                    const optics = root.find(controls, "glass-preview-lock-optics");
                    root.check(Math.abs(optics.thickness - 38.4) < 0.001, "Lock preview ignores prismatic optics: " + optics.thickness + ", " + controls.options.style);
                    controls.fixedScope = "input";
                } else {
                    root.check(controls.scope === "input" && controls.strength === 50,
                        "Input panel did not inherit General optics: " + controls.scope + ", " + slider.value + ", " + controls.strength);
                    controls.save("appearance", "dark");
                    slider.value = 30; slider.moved();
                    root.check(Tahow.Config.input.thickness === 18 && Tahow.Config.general.thickness === 30,
                        "Input panel optics were not independent");
                    controls.resetOverrides();
                    root.check(Tahow.Config.input.thickness === 30
                        && Tahow.Config.input.appearance === Tahow.Config.general.appearance,
                        "Input panel did not restore General");
                    console.log("GLASS_SETTINGS_OK");
                    Qt.quit();
                }
                root.stage++;
            } catch (error) { console.error("GLASS_SETTINGS_FAILED: " + error.message); Qt.quit(); }
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("GLASS_SETTINGS_FAILED: timed out at stage " + root.stage); Qt.quit(); } }
}
