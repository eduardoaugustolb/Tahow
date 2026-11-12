pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/material.js" as Material

// Colours, fonts and motion. Accent + light/dark follow your desktop theme.
Singleton {
    id: root

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    function home(p) { return (p || "").replace(/^~/, Quickshell.env("HOME")); }

    // ═══════════════════════════ FONTS ═══════════════════════════
    readonly property string font: {
        const f = Config.island.font;
        if (f && f !== "auto") return f;
        const fams = Qt.fontFamilies();
        const want = ["SF Pro Display", "SF Pro Text", "SF Pro", "Inter Display", "Inter", "Inter Variable"];
        for (let i = 0; i < want.length; i++) if (fams.indexOf(want[i]) >= 0) return want[i];
        return "sans-serif";
    }
    readonly property string iconFont: Config.iconFont

    // ═════════════════════ DESKTOP THEME SOURCES ═════════════════
    // GTK / GNOME settings (most theme switchers write these)
    property string gtkScheme: ""
    property string gtkAccent: ""
    property string gtkTheme: ""
    function parseGtk(line) {
        const m = line.match(/^\s*([a-z-]+):\s*'?([^']*)'?\s*$/);
        if (!m) return;
        if (m[1] === "color-scheme") gtkScheme = m[2];
        else if (m[1] === "accent-color") gtkAccent = m[2];
        else if (m[1] === "gtk-theme") gtkTheme = m[2];
    }
    Process {
        running: true
        command: ["sh", "-c",
            "for k in color-scheme accent-color gtk-theme; do " +
            "echo \"$k: $(gsettings get org.gnome.desktop.interface $k 2>/dev/null)\"; done"]
        stdout: SplitParser { onRead: l => root.parseGtk(l) }
    }
    Process {
        id: gtkMonitor
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface"]
        stdout: SplitParser { onRead: l => root.parseGtk(l) }
    }
    readonly property var gtkAccents: ({
        blue: "#3584e4", teal: "#2190a4", green: "#3a944a", yellow: "#c88800", orange: "#ed5b00",
        red: "#e62d42", pink: "#d56199", purple: "#9141ac", slate: "#6f8396"
    })

    // pywal / wallust (~/.cache/wal/colors.json)
    property string walAccent: ""
    property string walBg: ""
    FileView {
        path: root.home("~/.cache/wal/colors.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: { root.walAccent = ""; root.walBg = ""; }
        onLoaded: root.parseWal(text())
    }
    function parseWal(t) {
        try {
            const j = JSON.parse(t);
            walBg = (j.special && j.special.background) || "";
            let best = "", score = -1;
            for (let i = 1; i <= 6; i++) {
                const hex = j.colors && j.colors["color" + i];
                if (!hex) continue;
                const c = Qt.color(hex);
                const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.55));
                if (s > score) { score = s; best = hex; }
            }
            walAccent = best;
        } catch (e) {}
    }

    // matugen (or any JSON with a "primary" colour)
    property string matAccent: ""
    FileView {
        id: matFile
        path: root.home(Config.island.matugenPath)
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: root.matAccent = ""
        onLoaded: root.parseMat(text())
    }
    function parseMat(t) {
        try {
            const j = JSON.parse(t);
            const mode = dark ? "dark" : "light";
            const pick = o => !o ? "" : typeof o === "string" ? o : (o[mode] || o.default || o.color || "");
            const c = (j.colors && j.colors[mode] && j.colors[mode].primary)
                   || (j[mode] && j[mode].primary)
                   || (j.colors && pick(j.colors.primary))
                   || pick(j.primary) || pick(j.accent) || "";
            matAccent = typeof c === "string" ? c : "";
        } catch (e) { matAccent = ""; }
    }

    // Wallpaper: find the current image and pull its most vivid colour.
    // Works with swww/awww, hyprpaper, swaybg, waypaper, pywal's cache and common symlinks.
    property string detectedWallpaper: ""
    readonly property string wallpaper: Config.island.wallpaperPath ? root.home(Config.island.wallpaperPath) : (DesktopTheme.wallpaper || detectedWallpaper)
    Process {
        id: wallProc
        command: ["sh", "-c",
            "p=\"$1\"; " +
            "for t in swww awww; do [ -n \"$p\" ] && break; command -v $t >/dev/null || continue; " +
            "  p=$($t query 2>/dev/null | grep -o 'image: .*' | head -1 | cut -d' ' -f2-); done; " +
            "[ -z \"$p\" ] && p=$(ps -o args= -C swaybg 2>/dev/null | grep -oE '(-i|--image) +[^ ]+' | head -1 | awk '{print $2}'); " +
            "[ -z \"$p\" ] && [ -f \"$HOME/.config/waypaper/config.ini\" ] && p=$(grep -E '^wallpaper *=' \"$HOME/.config/waypaper/config.ini\" | head -1 | sed -E 's/^[^=]*= *//'); " +
            "[ -z \"$p\" ] && [ -f \"$HOME/.cache/wal/wal\" ] && p=$(cat \"$HOME/.cache/wal/wal\"); " +
            "case \"$p\" in \"~/\"*) p=\"$HOME/${p#\\~/}\";; esac; echo \"$p\"",
            "sh", root.home(Config.island.wallpaperPath)]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "" && p !== root.wallpaper && !DesktopTheme.wallpaper) root.detectedWallpaper = p;
            }
        }
    }
    Timer { interval: 15000; repeat: true; running: !DesktopTheme.wallpaper; triggeredOnStart: true; onTriggered: wallProc.running = true }
    Connections { target: Config.s; function onWallpaperPathChanged() { wallProc.running = true; } }
    ColorQuantizer {
        id: wallQuant
        source: root.wallpaper !== "" && /\.(png|jpe?g|webp|bmp|gif|tiff?)$/i.test(root.wallpaper) ? "file://" + root.wallpaper : ""
        depth: 4
        rescaleSize: 96
    }
    readonly property var wallColors: wallQuant.colors
    readonly property string wallAccent: {
        const cs = wallQuant.colors;
        if (!cs || cs.length === 0) return "";
        let best = null, score = -1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            // vivid, mid-lightness colours win (Material You-ish "source colour")
            const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4);
            if (s > score) { score = s; best = c; }
        }
        return best && best.hslSaturation > 0.12 ? best.toString() : "";
    }

    readonly property string hyprAccent: ""
    // ═════════════════════════ LIGHT / DARK ══════════════════════
    readonly property bool autoDark: {
        if (DesktopTheme.available) return DesktopTheme.dark;
        if (gtkScheme === "prefer-dark") return true;
        if (gtkScheme === "prefer-light") return false;
        if (/dark/i.test(gtkTheme)) return true;
        if (walBg !== "") return lum(Qt.color(walBg)) < 0.5;
        return true;
    }
    onDarkChanged: if (matFile.loaded) parseMat(matFile.text())
    readonly property bool dark: Config.island.style === "black" || (Config.island.appearance === "dark" ? true
                                : Config.island.appearance === "light" ? false : autoDark)

    // ═══════════════════════════ ACCENT ══════════════════════════
    readonly property string origin: {
        const src = Config.island.accentSource;
        if ((src === "auto" || src === "wallpaper" || src === "ryoku") && DesktopTheme.available) return "ryoku";
        if (src !== "auto") return src;
        if (matAccent !== "") return "matugen";
        if (walAccent !== "") return "wal";
        if (wallAccent !== "") return "wallpaper";
        if (gtkAccent !== "" && gtkAccent !== "blue") return "gtk";
        if (hyprAccent !== "") return "hyprland";
        return "default";
    }
    readonly property string originLabel: ({
        matugen: "Matugen", wal: "Pywal / Wallust", wallpaper: "Wallpaper", gtk: "GTK accent", hyprland: "Hyprland border",
        album: "Album art", custom: "Custom", default: "iOS Blue"
    })[origin] || origin

    readonly property color rawAccent: {
        let c = "";
        switch (origin) {
        case "ryoku": c = DesktopTheme.accent; break;
        case "matugen": c = matAccent; break;
        case "wal": c = walAccent; break;
        case "wallpaper": c = wallAccent; break;
        case "gtk": c = gtkAccents[gtkAccent] || ""; break;
        case "hyprland": c = hyprAccent; break;
        case "album": c = Hub.albumColorValid ? Hub.albumColor : ""; break;
        case "custom": c = Config.island.customAccent; break;
        }
        return c !== "" ? Qt.color(c) : (dark ? "#0a84ff" : "#007aff");
    }
    // keep it readable on glass
    function tune(c) {
        if (c.hslSaturation < 0.08) return c; // greys stay grey
        const s = Math.max(0.5, c.hslSaturation);
        const l = dark ? Math.min(0.72, Math.max(0.56, c.hslLightness))
                       : Math.min(0.52, Math.max(0.38, c.hslLightness));
        return Qt.hsla(c.hslHue, s, l, 1);
    }
    readonly property color accentTarget: tune(rawAccent)
    // Resolve each component's effective settings rather than borrowing the
    // island's overrides. Glass uses the same raw accent in every host.
    function materialAccent(options) {
        const source = options.accentSource;
        if (source === "custom") return Qt.color(options.customAccent);
        if (source === "album" && Hub.albumColorValid) return Hub.albumColor;
        if ((source === "auto" || source === "wallpaper" || source === "ryoku") && DesktopTheme.available) return DesktopTheme.accent;
        if (source === "matugen" && matAccent) return Qt.color(matAccent);
        if (source === "wal" && walAccent) return Qt.color(walAccent);
        if (source === "wallpaper" && wallAccent) return wallAccent;
        if (source === "gtk") return Qt.color(gtkAccents[gtkAccent] || "#0a84ff");
        if (source === "hyprland" && hyprAccent) return Qt.color(hyprAccent);
        if (source === "auto") {
            if (matAccent) return Qt.color(matAccent);
            if (walAccent) return Qt.color(walAccent);
            if (wallAccent) return wallAccent;
            if (gtkAccent && gtkAccent !== "blue") return Qt.color(gtkAccents[gtkAccent] || "#0a84ff");
            if (hyprAccent) return Qt.color(hyprAccent);
        }
        return Qt.color("#0a84ff");
    }
    function materialTint(options, isDark) { return Material.tint(isDark, options.glassAccentTint, materialAccent(options)); }
    readonly property color liveTarget: Config.island.albumTint && Hub.playing && Hub.albumColorValid ? tune(Hub.albumColor) : accentTarget

    property color accent: "#0a84ff"
    property color live: "#0a84ff"     // album-aware accent for media UI and glow
    onAccentTargetChanged: { a1.stop(); a1.from = accent; a1.to = accentTarget; a1.start(); }
    onLiveTargetChanged: { a2.stop(); a2.from = live; a2.to = liveTarget; a2.start(); }
    ColorAnimation { id: a1; target: root; property: "accent"; duration: 700; easing.type: Config.island.easing }
    ColorAnimation { id: a2; target: root; property: "live"; duration: 900; easing.type: Config.island.easing }
    Component.onCompleted: { accent = accentTarget; live = liveTarget; }

    readonly property color accentText: lum(accent) > 0.6 ? "#000000" : "#ffffff"

    // ═════════════════════ iOS SYSTEM COLOURS ════════════════════
    readonly property color red:    dark ? "#ff453a" : "#ff3b30"
    readonly property color orange: dark ? "#ff9f0a" : "#ff9500"
    readonly property color yellow: dark ? "#ffd60a" : "#ffcc00"
    readonly property color green:  dark ? "#30d158" : "#34c759"
    readonly property color teal:   dark ? "#40c8e0" : "#30b0c7"
    readonly property color blue:   dark ? "#0a84ff" : "#007aff"
    readonly property color indigo: dark ? "#5e5ce6" : "#5856d6"
    readonly property color purple: dark ? "#bf5af2" : "#af52de"
    readonly property color pink:   dark ? "#ff375f" : "#ff2d55"
    readonly property color gray:   "#8e8e93"
    // Control Center toggles: your theme accent, or the stock iOS colour
    function ccTint(ios) { return Config.island.ccAccent ? accent : ios; }
    // a second, softer tone of the accent for gradients
    readonly property color accent2: Qt.hsla(accent.hslHue, Math.max(0, accent.hslSaturation - 0.1),
                                             Math.min(0.85, accent.hslLightness + (dark ? 0.12 : 0.18)), 1)

    readonly property color fg:      dark ? "#ffffff" : "#000000"
    readonly property color fg2:     dark ? Qt.rgba(235/255, 235/255, 245/255, 0.62) : Qt.rgba(60/255, 60/255, 67/255, 0.62)
    readonly property color fg3:     dark ? Qt.rgba(235/255, 235/255, 245/255, 0.32) : Qt.rgba(60/255, 60/255, 67/255, 0.32)
    readonly property color fill:    dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color fill2:   dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color fill3:   dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color sep:     dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    // kept below the compositor's ignore_alpha (0.12, user.lua) in glass mode so shadows don't get frosted
    readonly property color shadow:  glass ? (dark ? Qt.rgba(0, 0, 0, 0.11) : Qt.rgba(0, 0, 0, 0.08))
                                           : (dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.22))

    // Glass surface tint (the compositor blur sits underneath)
    readonly property bool glass: Config.island.style !== "black"
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }
    readonly property real tintMix: Config.island.glassAccentTint ? (dark ? 0.10 : 0.07) : 0
    readonly property color glassBase: Material.base(dark)
    readonly property color glassBody: materialTint(Config.island, dark)
    readonly property real glassA: Material.opacity(Config.island.glassOpacity)
    readonly property color glassTint: !glass ? "#000000" : alpha(glassBody, glassA)
    // top/bottom of the glass body (a gentle vertical falloff reads as thickness)
    readonly property color glassTop: !glass ? "#000000" : alpha(mix(glassBody, Qt.rgba(1, 1, 1, 1), dark ? 0.05 : 0.35), glassA)
    readonly property color glassBottom: !glass ? "#000000" : alpha(mix(glassBody, Qt.rgba(0, 0, 0, 1), dark ? 0.25 : 0.02), glassA)
    // Elevated cards on top of glass (banners, widgets)
    readonly property color card: dark ? Qt.rgba(0.11, 0.11, 0.13, Math.min(0.92, Config.island.glassOpacity + 0.15))
                                       : Qt.rgba(1, 1, 1, Math.min(0.92, Config.island.glassOpacity + 0.2))
    // Settings window
    readonly property color window: dark ? Qt.rgba(0.07, 0.07, 0.08, 0.86) : Qt.rgba(0.95, 0.95, 0.97, 0.88)
    readonly property color group:  dark ? Qt.rgba(0.17, 0.17, 0.19, 0.92) : Qt.rgba(1, 1, 1, 0.95)

    // ═══════════════════════════ MOTION ══════════════════════════
    readonly property bool reduced: Config.island.motion === "reduced"
    readonly property real spring: ({ gentle: 3.0, balanced: 3.6, bouncy: 4.2, reduced: 7 })[Config.island.motion] || 3.6
    readonly property real damping: ({ gentle: 0.42, balanced: 0.30, bouncy: 0.21, reduced: 1.0 })[Config.island.motion] || 0.3
    readonly property int fast: reduced ? 1 : Math.max(1, Config.island.fastDuration)
    readonly property int med: reduced ? 1 : Math.max(1, Config.island.mediumDuration)
}
