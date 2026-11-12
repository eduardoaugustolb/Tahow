import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../lib/metrics.js" as Metrics

// Data-only desktopWidget service. No host internals or installed Python
// singletons are imported. Polling stops while the host disables this service.
Item {
    id: root
    property string kind: "cpu"
    property var pluginApi: null
    property bool active: true
    readonly property var settings: pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings : ({})
    readonly property int refreshInterval: Metrics.interval(settings.refreshInterval)
    property var metric: Metrics.unavailable()
    property var previousCpu: null
    readonly property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    readonly property var players: active && kind === "media" ? Mpris.players.values : []
    readonly property var player: {
        // Playing wins, then a loaded/paused track, then a controllable player.
        // Access isPlaying/trackTitle so selection follows playback changes.
        const ordered = players.slice().sort((a, b) => String(a.dbusName || "").localeCompare(String(b.dbusName || "")));
        return ordered.find(p => p.isPlaying) || ordered.find(p => p.trackTitle) || ordered.find(p => p.canControl) || null;
    }
    readonly property bool available: active && (kind === "media" ? player !== null : kind === "session" || kind === "clock" ? true : metric.available)
    readonly property real value: kind === "media" ? (length > 0 ? Metrics.fraction(position / length) : 0) : Metrics.fraction(metric.value)
    readonly property string valueText: kind === "session" ? username : metric.valueText
    readonly property string detailText: kind === "media" ? artist : metric.detailText
    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string artUrl: player ? Metrics.artwork(player.trackArtUrl) : ""
    readonly property real position: player && player.positionSupported ? Math.max(0, player.position) : 0
    readonly property real length: player && player.lengthSupported ? Math.max(0, player.length) : 0
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool canSeek: player !== null && player.canControl && player.canSeek && player.positionSupported && length > 0
    readonly property bool canTogglePlaying: player !== null && player.canTogglePlaying
    readonly property bool canPrevious: player !== null && player.canGoPrevious
    readonly property bool canNext: player !== null && player.canGoNext
    readonly property string temperatureScript: pluginApi && pluginApi.pluginDir
        ? pluginApi.pluginDir + "/bin/read-temperature.ts"
        : Qt.resolvedUrl("../bin/read-temperature.ts").toString().replace(/^file:\/\//, "")

    function sampleNow() {
        if (!active) return;
        if (kind === "cpu") cpuFile.reload();
        else if (kind === "memory") memoryFile.reload();
        else if (kind === "disk" && !diskProcess.running) diskProcess.running = true;
        else if (kind === "temperature" && !temperatureProcess.running) temperatureProcess.running = true;
    }
    onActiveChanged: {
        previousCpu = null;
        if (active) sampleNow();
        else { diskProcess.running = false; temperatureProcess.running = false; }
    }
    onKindChanged: { previousCpu = null; metric = Metrics.unavailable(); }
    FileView {
        id: cpuFile
        path: root.active && root.kind === "cpu" ? "/proc/stat" : ""
        printErrors: false
        onLoaded: {
            const current = Metrics.cpuCounters(text());
            root.metric = Metrics.cpuUsage(root.previousCpu, current);
            root.previousCpu = current;
        }
        onLoadFailed: { root.previousCpu = null; root.metric = Metrics.unavailable(); }
    }
    FileView {
        id: memoryFile
        path: root.active && root.kind === "memory" ? "/proc/meminfo" : ""
        printErrors: false
        onLoaded: root.metric = Metrics.memory(text())
        onLoadFailed: root.metric = Metrics.unavailable()
    }
    Process {
        id: diskProcess
        command: ["df", "-Pk", "--", "/"]
        environment: ({LC_ALL: "C"})
        stdout: StdioCollector { onStreamFinished: if (root.active && root.kind === "disk") root.metric = Metrics.disk(text) }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0 && root.kind === "disk") root.metric = Metrics.unavailable(); }
    }
    Process {
        id: temperatureProcess
        command: ["bun", root.temperatureScript]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active || root.kind !== "temperature") return;
                try { root.metric = Metrics.temperature(JSON.parse(text), root.settings.unit); }
                catch (_) { root.metric = Metrics.unavailable(); }
            }
        }
        onExited: (exitCode, exitStatus) => { if (exitCode !== 0 && root.kind === "temperature") root.metric = Metrics.unavailable(); }
    }
    Timer {
        interval: root.refreshInterval; running: root.active && ["cpu", "memory", "disk", "temperature"].indexOf(root.kind) >= 0
        repeat: true; triggeredOnStart: true
        onTriggered: root.sampleNow()
    }
    Timer {
        interval: 1000; running: root.active && root.kind === "media" && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }
    function togglePlaying() { if (active && canTogglePlaying) player.togglePlaying(); }
    function previous() { if (active && canPrevious) player.previous(); }
    function next() { if (active && canNext) player.next(); }
    function seek(fraction) { if (active && canSeek && Number.isFinite(Number(fraction))) player.position = Metrics.fraction(Number(fraction)) * length; }
    // Called only by an explicit UI action. The face confirms destructive
    // actions first; construction, timers and settings never call this method.
    function session(action) {
        if (!active || kind !== "session" || sessionProcess.running) return;
        const command = Metrics.sessionCommand(action);
        if (!command.length) return;
        sessionProcess.command = command;
        sessionProcess.running = true;
    }
    Process { id: sessionProcess }
}
