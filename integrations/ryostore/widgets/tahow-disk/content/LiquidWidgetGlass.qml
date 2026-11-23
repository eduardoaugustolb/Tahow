// SPDX-License-Identifier: AGPL-3.0-only
import QtQuick
import Quickshell
import Quickshell.Io
Item {
    id: root
    property var settings: ({})
    property var screen: null
    property color tint: "#172131"
    property real radius: 24
    property bool enabledMaterial: false
    readonly property bool followGeneral: root.settings && root.settings.followGeneral === true
    FileView {
        id: tahowSettings
        path: (Quickshell.env("HOME") || "") + "/.config/tahow-shell/settings.json"
        preload: true
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    readonly property var generalConfig: {
        try { return JSON.parse(tahowSettings.text()); } catch (_) { return ({}); }
    }
    function cfg(key, fallback) {
        if (root.followGeneral && root.generalConfig && root.generalConfig[key] !== undefined) {
            const v = root.generalConfig[key];
            return (typeof v === "number" && Number.isFinite(v)) ? v : v;
        }
        return fallback;
    }
    readonly property var effectiveSettings: {
        if (!root.followGeneral) return root.settings || ({});
        const g = root.generalConfig || ({});
        const s = Object.assign({}, root.settings || ({}));
        for (const k of ["bezel","thickness","ior","dispersion","frost","glassOpacity","innerShadow","rimStrength","glassAccentTint","glassRim"]) {
            if (g[k] !== undefined) s[k] = g[k];
        }
        return s;
    }
    readonly property bool ready: compositor.ready
    function number(key, fallback, min, max) {
        const value = Number(root.effectiveSettings[key]);
        return Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;
    }
    CompositorGlass {
        id: compositor; anchors.fill: parent
        target: "ryoku-widgets"; active: root.enabledMaterial
        prism: root.settings.material === "prism"
        radius: root.radius
        bezel: root.number("bezel",14,0,40)
        thickness: root.number("thickness",24,0,60)
        ior: root.number("ior",1.5,1,2.5)
        dispersion: root.number("dispersion",0.08,0,0.2)
        innerShadow: root.number("innerShadow",1,0,1)
        frost: root.number("frost",8,0,30)
        rim: root.effectiveSettings.glassRim === false ? 0 : root.number("rimStrength",1,0,1)
    }
}
