import QtQuick
import QtQuick.Window
import QtQuick.Effects
Item {
    id: root
    property bool refraction: true
    property real radius: 20
    property color tint: Theme.glassTint
    property bool rim: root.refraction && Config.island.glassRim && Theme.glass
    property bool sheen: Theme.glass
    property bool shadow: true
    property real shadowBlur: 30
    property real shadowY: 10
    property color glowColor: Theme.accent
    property real glowStrength: 0
    readonly property real r: Math.max(0, Math.min(radius, height / 2, width / 2))
    readonly property var texture: Host.backdrops[Screen.name] || null
    RectangularShadow { anchors.fill: parent; visible: root.shadow; radius: root.r; blur: root.shadowBlur; offset.y: root.shadowY; color: Theme.shadow }
    Rectangle {
        anchors.fill: parent; radius: root.r
        gradient: Gradient {
            GradientStop { position: 0; color: root.refraction ? Theme.alpha(root.tint,Math.max(0.12,Config.island.glassOpacity)) : Theme.alpha(Theme.mix(root.tint,Qt.rgba(1,1,1,1),Theme.dark ? 0.22 : 0.44),0.64) }
            GradientStop { position: 0.48; color: root.refraction ? Theme.alpha(root.tint,Math.max(0.12,Config.island.glassOpacity)) : Theme.alpha(Theme.mix(root.tint,Theme.accent,0.08),0.48) }
            GradientStop { position: 1; color: root.refraction ? Theme.alpha(root.tint,Math.max(0.12,Config.island.glassOpacity)) : Theme.alpha(Theme.mix(root.tint,Qt.rgba(1,1,1,1),Theme.dark ? 0.10 : 0.3),0.58) }
        }
        border.width: root.refraction ? 0 : 1
        border.color: Theme.alpha(Theme.mix(Theme.accent,Qt.rgba(1,1,1,1),0.6),Theme.dark ? 0.36 : 0.65)
    }
    Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: Math.max(0,root.r-1.5); color: "transparent"; visible: !root.refraction; border.width: 0.5; border.color: Qt.rgba(1,1,1,Theme.dark ? 0.08 : 0.34) }
    NativeGlass {
        id: glass
        anchors.fill: parent; visible: root.refraction && Theme.glass && root.texture !== null
        src: root.texture
        sourceRect: {
            let ancestor = root;
            while (ancestor) { ancestor.x; ancestor.y; ancestor.width; ancestor.height; ancestor.scale; ancestor = ancestor.parent; }
            if (root.Window.window) { root.Window.window.x; root.Window.window.y; }
            const p = root.mapToGlobal(0, 0);
            return Qt.rect((p.x - Screen.virtualX) / Math.max(1, Screen.width), (p.y - Screen.virtualY) / Math.max(1, Screen.height), root.width / Math.max(1, Screen.width), root.height / Math.max(1, Screen.height));
        }
        topLeftRadius: root.r; topRightRadius: root.r; bottomLeftRadius: root.r; bottomRightRadius: root.r
        tintColor: root.tint; tintAmount: Theme.glassA
        bezel: Config.island.bezel; thickness: Config.island.thickness; ior: Config.island.ior; dispersion: Config.island.dispersion
        frost: Math.max(0, Config.island.frost / 5); rim: root.rim ? 0.25 : 0
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: 1
        radius: Math.max(0, root.r - 1)
        visible: glass.visible
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 1); opacity: Theme.glassA
    }
    Rectangle { anchors.fill: parent; radius: root.r; color: "transparent"; border.width: root.rim ? 1 : 0; border.color: Theme.alpha(Theme.accent, Theme.dark ? 0.2 : 0.35) }
}
