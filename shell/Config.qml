pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/paths.js" as Paths

// Persistent settings. Edited live from the Island's own settings window
// (SUPER+, or the gear), stored under ~/.config/tahow-shell/settings.json.
// The legacy ~/.config/tahoe-shell directory is still read when the new one
// has no settings file yet, and is migrated on the first write.
// You can also hand-edit the JSON; changes are picked up instantly.
Singleton {
    id: root

    readonly property string configHome: Paths.configHome({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    })
    readonly property string canonicalDir: Paths.canonicalDir({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    })
    readonly property string legacyDir: Paths.legacyDir({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    })
    // The canonical directory owns every write. The legacy directory is only
    // read (and copied over) when the canonical one has no settings file.
    readonly property string dir: root.canonicalDir
    readonly property string iconFont: "Material Symbols Rounded"

    readonly property var general: adapter
    readonly property var island: effective("island")
    readonly property var palette: effective("palette")
    readonly property var lockscreen: effective("lockscreen")
    function effective(scope) {
        const values = {};
        for (const key in defaults) values[key] = adapter[key];
        const overrides = adapter.overrides;
        return Object.assign(values, overrides && overrides[scope] || {});
    }
    function value(scope, key) { return scope === "general" ? adapter[key] : effective(scope)[key]; }
    function set(scope, key, value) {
        if (scope === "general") { adapter[key] = value; return; }
        const all = Object.assign({}, adapter.overrides || {});
        all[scope] = Object.assign({}, all[scope] || {});
        all[scope][key] = value;
        adapter.overrides = all;
    }
    function inherit(scope) {
        const all = Object.assign({}, adapter.overrides || {});
        delete all[scope]; adapter.overrides = all;
    }
    function inheritKeys(scope, keys) {
        if (["island", "palette", "lockscreen"].indexOf(scope) < 0 || !Array.isArray(keys)) return;
        const all = Object.assign({}, adapter.overrides || {});
        if (!all[scope]) return;
        const values = Object.assign({}, all[scope]);
        let changed = false;
        for (const key of keys) {
            if (typeof key === "string" && Object.prototype.hasOwnProperty.call(values, key)) {
                delete values[key]; changed = true;
            }
        }
        if (!changed) return;
        if (Object.keys(values).length) all[scope] = values;
        else delete all[scope];
        adapter.overrides = all;
    }
    property alias s: adapter
    property bool resetting: false
    property bool canonicalReady: false
    property bool legacyReady: false
    property bool canonicalProbed: false
    property bool legacyProbed: false
    property bool initialized: false
    property bool canonicalMissing: false
    property bool legacyMissing: false
    property string persistenceError: ""
    readonly property bool probesDone: root.canonicalProbed && root.legacyProbed
    readonly property string settingsPath: Paths.settingsPath({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    }, root.canonicalReady, root.legacyReady)

    function readSettings(view) {
        const text = view.text(); // blockLoading forces completion before choosing a source.
        if (!view.loaded) return null;
        try {
            const values = JSON.parse(text);
            if (!values || typeof values !== "object" || Array.isArray(values)) throw new Error("Expected a settings object");
            return values;
        } catch (error) {
            persistenceError = "Cannot parse preferences: " + view.path;
            console.error(persistenceError);
            return null;
        }
    }
    function persist() {
        if (!initialized || resetting) return;
        file.writeAdapter();
    }
    function initialize() {
        // Resolve the canonical file synchronously. A legacy read must never
        // race a separate existence probe and overwrite newer preferences.
        const current = readSettings(file);
        canonicalProbed = true;
        if (current !== null) {
            canonicalReady = true;
            legacyProbed = true;
            initialized = true;
            return;
        }
        // Unreadable/corrupt files are not fresh installs. Preserve them.
        if (!canonicalMissing) return;
        const legacy = readSettings(legacyFile);
        legacyProbed = true;
        legacyReady = legacy !== null;
        if (!legacyReady && !legacyMissing) return;
        if (legacyReady) {
            for (const key in defaults) {
                if (Object.prototype.hasOwnProperty.call(legacy, key)) adapter[key] = legacy[key];
            }
            if (legacy.overrides && typeof legacy.overrides === "object") adapter.overrides = legacy.overrides;
        }
        initialized = true;
        persist();
    }
    Component.onCompleted: initialize()

    // Upstream reset deleted the file and reloaded the whole Quickshell
    // instance; here that would reload the entire Ryoku shell. Instead every
    // default is mirrored below and applied in place.
    function reset() {
        resetting = true;
        adapter.overrides = ({});
        const d = defaults;
        for (const k in d) {
            try { adapter[k] = d[k]; } catch (e) {}
        }
        resetting = false;
        persist();
    }

    // Mirrors the JsonAdapter defaults below; shared by reset and legacy migration.
    readonly property var defaults: ({
        language: "auto",
        loginFollowWallpaper: true,
        reloadCoverFollowWallpaper: false,
        lockFooterScale: 1.12,
        lockRim: 0.22,
        lockTint: 0.035,
        lockThickness: 14,
        lockIor: 1.25,
        lockDispersion: 0.08,
        lockEnergy: 0.05,
        lockBezel: 6,
        compactPadding: 18,
        settingsAppearance: "light",
        takeover: true,
        dnd: false,
        islandEnabled: true,
        paletteEnabled: true,
        lockscreenEnabled: true,
        easing: 6,
        fastDuration: 180,
        mediumDuration: 300,
        palettePosition: 0.28,
        columns: 7,
        matWidth: 82,
        hiddenApps: [],
        pinnedApps: [],
        screenCapture: false,
        bezel: 6,
        thickness: 8,
        ior: 1.2,
        dispersion: 0.08,
        frost: 12,
        pamService: "login",
        style: "glass",
        appearance: "auto",
        glassOpacity: 0.55,
        glassRim: true,
        glassAccentTint: true,
        glow: true,
        accentSource: "auto",
        customAccent: "#0a84ff",
        matugenPath: "~/.cache/matugen/colors.json",
        wallpaperPath: "",
        albumTint: true,
        font: "auto",
        overlayBar: true,
        reserveSpace: true,
        topMargin: 6,
        outerGaps: 16,
        motion: "balanced",
        use24h: false,
        showAmPm: false,
        showSeconds: false,
        showBattery: true,
        showPrivacy: true,
        workspaceFlash: true,
        splitActivities: true,
        activityClock: "split",
        hoverPeek: true,
        hoverDelay: 260,
        visualizer: true,
        trackChangePeek: true,
        spinArt: true,
        notifications: true,
        notifStyle: "banner",
        bannerTimeout: 5,
        previews: "always",
        notifSound: false,
        soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga",
        groupByApp: true,
        dndAllowCritical: true,
        weather: true,
        locationMode: "auto",
        manualLat: 0,
        manualLon: 0,
        manualName: "",
        units: "metric",
        ccAccent: true,
        nightLightTemp: 4000,
        osdPopups: false,
        osdTimeout: 1600,
        confirmPower: true
    })

    FileView {
        id: legacyFile
        path: root.legacyDir + "/settings.json"
        preload: false
        blockLoading: true
        printErrors: false
        // Migration is a one-time startup decision, never a live legacy writer.
        onLoadFailed: error => {
            root.legacyMissing = error === FileViewError.FileNotFound;
            if (!root.legacyMissing) {
                root.persistenceError = "Cannot read legacy preferences: " + path + " (" + FileViewError.toString(error) + ")";
                console.error(root.persistenceError);
            }
        }
    }

    FileView {
        id: file
        path: root.canonicalDir + "/settings.json"
        preload: false
        watchChanges: true
        blockLoading: true
        // Preferences are small. Complete each atomic write before returning
        // so shutdown and self-watch notifications cannot discard pending edits.
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onFileChanged: {
            if (root.resetting) return;
            root.resetting = true;
            reload();
            root.initialized = root.readSettings(file) !== null;
            root.resetting = false;
        }
        onAdapterUpdated: root.persist()
        onLoaded: { root.canonicalReady = true; root.canonicalMissing = false; }
        onLoadFailed: error => {
            root.canonicalMissing = error === FileViewError.FileNotFound;
            if (!root.canonicalMissing) {
                root.persistenceError = "Cannot read preferences: " + path + " (" + FileViewError.toString(error) + ")";
                console.error(root.persistenceError);
            }
        }
        onSaved: { root.canonicalReady = true; root.persistenceError = ""; }
        onSaveFailed: error => {
            root.persistenceError = "Cannot save preferences: " + path + " (" + FileViewError.toString(error) + ")";
            console.error(root.persistenceError);
        }

        JsonAdapter {
            id: adapter
            property string language: "auto"
            property bool loginFollowWallpaper: true
            property bool reloadCoverFollowWallpaper: false
            property real lockFooterScale: 1.12
            property real lockRim: 0.22
            property real lockTint: 0.035
            property real lockThickness: 14
            property real lockIor: 1.25
            property real lockDispersion: 0.08
            property real lockEnergy: 0.05
            property real lockBezel: 6
            property int compactPadding: 18
            property string settingsAppearance: "light"
            property var overrides: ({})
            property bool takeover: true            // stop mako/dunst/swaync on start
            property bool dnd: false

            property bool islandEnabled: true
            property bool paletteEnabled: true
            property bool lockscreenEnabled: true
            property int easing: 6
            property int fastDuration: 180
            property int mediumDuration: 300
            property real palettePosition: 0.28
            property int columns: 7
            property int matWidth: 82
            property var hiddenApps: []
            property var pinnedApps: []
            property bool screenCapture: false
            property real bezel: 6
            property real thickness: 8
            property real ior: 1.2
            property real dispersion: 0.08
            property real frost: 12
            property string pamService: "login"

            // ── Appearance ──
            property string style: "glass"          // glass | black
            property string appearance: "auto"      // auto | dark | light
            property real glassOpacity: 0.55        // tint strength behind the blur
            property bool glassRim: true            // liquid-glass specular edge
            property bool glassAccentTint: true     // mix a hint of the accent into the glass
            property bool glow: true
            property string accentSource: "auto"    // auto | wallpaper | wal | matugen | ryoku | gtk | album | custom
            property string customAccent: "#0a84ff"
            property string matugenPath: "~/.cache/matugen/colors.json"
            property string wallpaperPath: ""       // empty = detect (swww, hyprpaper, swaybg, waypaper…)
            property bool albumTint: true           // tint island with album colour while music plays
            property string font: "auto"            // auto = SF Pro if installed, else Inter

            // ── Island ──
            property bool overlayBar: true
            property bool reserveSpace: true        // push maximized/tiled windows below the island (bar-like)
            property int topMargin: 6
            property int outerGaps: 16              // the compositor's outer gaps; trims the reserved strip
            property string motion: "balanced"      // gentle | balanced | bouncy | reduced
            property bool use24h: false
            property bool showAmPm: false
            property bool showSeconds: false
            property bool showBattery: true
            property bool showPrivacy: true
            property bool workspaceFlash: true
            property bool splitActivities: true     // iOS-style second bubble
            property string activityClock: "split"  // split | inline | hidden — the time while music/timers run
            property bool hoverPeek: true
            property int hoverDelay: 260

            // ── Media ──
            property bool visualizer: true
            property bool trackChangePeek: true
            property bool spinArt: true

            // ── Notifications ──
            // The Ryoku shell owns the freedesktop notification daemon, so the
            // island wraps the shell's server instead of running its own.
            property bool notifications: true       // island takes the banner display over from the shell
            property string notifStyle: "banner"    // banner | island | corner
            property int bannerTimeout: 5
            property string previews: "always"      // always | never
            property bool notifSound: false         // the shell already plays its own cue
            property string soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga"
            property bool groupByApp: true
            property bool dndAllowCritical: true    // critical banners pass through the shell's own Focus

            // ── Weather + location ──
            property bool weather: true
            property string locationMode: "auto"    // auto (GeoClue → IP) | ip | manual
            property real manualLat: 0
            property real manualLon: 0
            property string manualName: ""
            property string units: "metric"         // metric | imperial

            // ── Controls ──
            property bool ccAccent: true            // Control Center toggles use your theme accent
            property int nightLightTemp: 4000       // Night Shift temperature (K), applied to the shell's Nightlight
            property bool osdPopups: false          // island volume/mic/brightness pills (the shell draws its own OSD)
            property int osdTimeout: 1600
            property bool confirmPower: true
        }
    }
}
