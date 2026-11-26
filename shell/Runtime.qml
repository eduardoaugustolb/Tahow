import QtQuick
import Quickshell
import Quickshell.Io
import "apps" as Apps
Scope {
    id: root
    property bool ownsLock: true
    CommandPalette {
        id: commandPalette
        actionHandler: root.runSpotlightAction
        historyProvider: inputSurface
    }
    function runSpotlightAction(action) {
        if (lockLoader.item?.requested) return;
        switch (action) {
        case "timer": Hub.startTimer(1500); break;
        case "mic": Hub.toggleMic(); break;
        case "screenshot": Hub.screenshot(); break;
        case "focus": Notifs.toggleDnd(); break;
        }
    }
    Apps.DesktopApps { id: desktopApps }
    InputPanel {
        id: inputSurface
        externalHistoryVisible: commandPalette.wantsClipboardHistory
    }
    CapturePanel {
        id: capturePanel
        onRecordingProcessIdChanged: Hub.recordingProcessId = recordingProcessId
    }
    function toggleCapture() {
        if (lockLoader.item?.requested) return "locked";
        Hub.expanded = false;
        commandPalette.hide();
        inputSurface.visible = false;
        return capturePanel.toggle();
    }
    function toggleInput(page) {
        if (lockLoader.item?.requested) return;
        commandPalette.hide();
        inputSurface.toggle(page);
    }
    Variants { model: Config.s.islandEnabled ? Quickshell.screens : []; IslandWindow {} }
    LazyLoader { id: settingsLoader; active: Hub.settingsOpen; SettingsWindow {} }
    Loader { id: lockLoader; active: root.ownsLock; source: "Lockscreen.qml" }
    Connections {
        target: lockLoader.item
        function onRequestedChanged() {
            if (!lockLoader.item.requested) return;
            commandPalette.hide();
            inputSurface.visible = false;
            capturePanel.visible = false;
            desktopApps.closeWindows();
        }
    }
    Connections {
        target: Hub
        function onCaptureRequested() { root.toggleCapture(); }
        function onStopTahowRecording() { capturePanel.stop(); }
        function onClosePalette() { commandPalette.hide(); }
        function onLockRequested() { if (lockLoader.item && Config.s.lockscreenEnabled) lockLoader.item.requested = true; }
        function onLauncherOpenChanged() { if (Hub.launcherOpen && Config.s.paletteEnabled) { Hub.launcherOpen = false; commandPalette.show(Hub.launcherScreen); } }
    }

    function openDesktopApp(app) {
        if (lockLoader.item?.requested) return;
        desktopApps.open(app);
    }
    Connections {
        target: Host
        function onOpenDesktopAppRequested(app) {
            root.openDesktopApp(app);
        }
        function onOpenSettingsRequested() { Hub.openSettings(); }
    }
    IpcHandler {
        target: "tahoe"
        function launcher(): void { if (Config.s.paletteEnabled) commandPalette.toggle(""); }
        function openLauncher(mon: string): void { if (Config.s.paletteEnabled) commandPalette.show(mon); }
        function openApplications(mon: string): void { if (Config.s.paletteEnabled) commandPalette.show(mon, true); }
        function openApp(app: string): void { root.openDesktopApp(app); }
        function files(): void { root.openDesktopApp("files"); }
        function closeLauncher(): void { commandPalette.hide(); }
        function setDispersion(amount: real): void {
            if (!Number.isFinite(amount)) return;
            const value = Math.max(0, Math.min(0.2, amount));
            const overrides = Object.assign({}, Config.s.overrides || {});
            overrides.island = Object.assign({}, overrides.island || {}, {dispersion: value});
            overrides.palette = Object.assign({}, overrides.palette || {}, {dispersion: value});
            overrides.lockscreen = Object.assign({}, overrides.lockscreen || {}, {lockDispersion: value});
            Config.s.overrides = overrides;
        }
        function state(): string { return JSON.stringify(Object.assign(commandPalette.stateDump(), {settingsOpen: Hub.settingsOpen, settingsPage: settingsLoader.item ? settingsLoader.item.page : -1, language: I18n.lang, islandDark: Theme.dark, captureCount: Host.captureCount, islands: Host.windows.map(w => w.layoutDump())})); }
        function closeSettings(): void { Hub.settingsOpen = false; }
        function settingsTab(section: string): void { Hub.openSettings(); Qt.callLater(() => { const index = section === "wallpaper" ? 24 : section === "input" ? 23 : ["general","island","palette","lockscreen","system","shortcuts","glass"].indexOf(section); if (settingsLoader.item && index >= 0) settingsLoader.item.page = index; }); }
        function settings(): void { Hub.openSettings(); }
        function clipboard(): void { root.toggleInput(1); }
        function emojis(): void { root.toggleInput(2); }
        function capture(): string { return root.toggleCapture(); }
    }
    Connections {
        target: Config
        function onInitializedChanged() { if (Config.initialized) root.restoreWallpaper(); }
    }
    function restoreWallpaper() {
        if (ownsLock && Config.initialized && Config.s.desktopWallpaperPath)
            DesktopWallpaper.apply(Config.s.desktopWallpaperPath, Config.s.desktopWallpaperMode, true);
    }
    Component.onCompleted: { Hub.armed; Notifs.ready; Theme.dark; LoginWallpaper.status; restoreWallpaper(); }
}
