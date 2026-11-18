// SPDX-License-Identifier: AGPL-3.0-only
import QtQuick
Item {
    id: root
    property var settings: ({})
    property var screen: null
    property color tint: "#172131"
    property real radius: 24
    property bool enabledMaterial: false
    readonly property bool ready: compositor.ready
    function number(key, fallback, min, max) {
        const value = Number(settings[key]);
        return Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;
    }
    CompositorGlass {
        id: compositor; anchors.fill: parent
        target: "ryoku-widgets"; active: root.enabledMaterial
        radius: root.radius
        bezel: root.number("bezel",14,0,40)
        thickness: root.number("thickness",24,0,60)
        ior: root.number("ior",1.5,1,2.5)
        dispersion: root.number("dispersion",0.08,0,0.2)
        frost: root.number("frost",8,0,30)
    }
}
