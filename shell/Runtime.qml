import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: root
    property bool ownsLock: true
    CommandPalette { id: commandPalette }
    Variants { model: Config.s.islandEnabled ? Quickshell.screens : []; IslandWindow {} }
    LazyLoader { id: settingsLoader; active: Hub.settingsOpen; SettingsWindow {} }
    Loader { id: lockLoader; active: root.ownsLock; source: "Lockscreen.qml" }
    Connections {
        target: Hub
        function onClosePalette() { commandPalette.hide(); }
        function onLockRequested() { if (lockLoader.item && Config.s.lockscreenEnabled) lockLoader.item.requested = true; }
        function onLauncherOpenChanged() { if (Hub.launcherOpen && Config.s.paletteEnabled) { Hub.launcherOpen = false; commandPalette.show(Hub.launcherScreen); } }
    }
    IpcHandler {
        target: "tahoe"
        function launcher(): void { if (Config.s.paletteEnabled) commandPalette.toggle(""); }
        function openLauncher(mon: string): void { if (Config.s.paletteEnabled) commandPalette.show(mon); }
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
        function settingsTab(section: string): void { Hub.openSettings(); Qt.callLater(() => { const index = ["general","island","palette","lockscreen","system","shortcuts","glass"].indexOf(section); if (settingsLoader.item && index >= 0) settingsLoader.item.page = index; }); }
        function settings(): void { Hub.openSettings(); }
    }
    Component.onCompleted: { Hub.armed; Notifs.ready; Theme.dark; }
}
