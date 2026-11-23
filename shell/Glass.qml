import QtQuick
import "lib/material.js" as Material
import QtQuick.Window
import QtQuick.Effects
Item {
    id: root
    property var options: Config.island
    readonly property bool glassEnabled: options.style !== "black"
    readonly property real tintOpacity: Material.opacity(options.glassOpacity)
    property string compositorTarget: "quickshell:island"
    property bool useCompositor: true
    readonly property bool compositorAvailable: compositor.materialAvailable
    property bool refraction: true
    property real refractionAmount: 1
    property real innerShadow: options.innerShadow
    property real bezel: options.bezel
    property real radius: 20
    property color tint: Theme.glassTint
    property bool rim: root.refraction && root.options.glassRim && root.glassEnabled
    property bool sheen: Theme.glass
    property bool shadow: true
    property real shadowBlur: 30
    property real shadowY: 10
    property color glowColor: Theme.accent
    property real glowStrength: 0
    readonly property real r: Math.max(0, Math.min(radius, height / 2, width / 2))
    property var texture: Host.backdrops[Screen.name] || null
    property rect textureRect: {
        let ancestor = root;
        while (ancestor) { ancestor.x; ancestor.y; ancestor.width; ancestor.height; ancestor.scale; ancestor = ancestor.parent; }
        if (root.Window.window) { root.Window.window.x; root.Window.window.y; }
        const p = root.mapToGlobal(0, 0);
        return Qt.rect((p.x - Screen.virtualX) / Math.max(1, Screen.width), (p.y - Screen.virtualY) / Math.max(1, Screen.height), root.width / Math.max(1, Screen.width), root.height / Math.max(1, Screen.height));
    }
    property bool sampledFrame: false
    onTextureChanged: sampledFrame = false
    onRefractionChanged: sampledFrame = false
    // QSB shaders can retain Uncompiled with a cached RHI pipeline. Wait for
    // an actual submitted frame instead of using Compiled as a readiness gate.
    readonly property bool compositorReady: compositor.ready
    // A fully clipped consumer needs no texture; unsupported transforms still
    // require their QML fallback even when the primary island is already native.
    readonly property bool snapshotFallbackNeeded: root.refraction && root.glassEnabled && root.options.screenCapture && !compositorReady
        && (!compositor.geometry.supported || (compositor.geometry.clipWidth > 0 && compositor.geometry.clipHeight > 0))
    readonly property bool liquidReady: compositor.ready || (glass.visible && sampledFrame && glass.status !== ShaderEffect.Error)
    function materialState() { return {provider: compositor.ready ? "compositor-live" : root.texture !== null ? "snapshot" : "simulated", compositorAvailable: compositor.available, compositorReady: compositor.ready, screen: Screen.name, textureReady: texture !== null, shaderVisible: glass.visible, shaderStatus: glass.status, shaderLog: glass.log, themeGlass: root.glassEnabled}; }
    property real liquidMix: liquidReady ? 1 : 0
    Behavior on liquidMix { NumberAnimation { duration: Theme.reduced ? 1 : 150; easing.type: Easing.InOutQuad } }
    Connections {
        target: root.Window.window
        enabled: glass.visible && !root.sampledFrame
        function onFrameSwapped() { root.sampledFrame = true; }
    }
    RectangularShadow { anchors.fill: parent; visible: root.shadow; radius: root.r; blur: root.shadowBlur; offset.y: root.shadowY; color: Theme.shadow }
    Rectangle {
        anchors.fill: parent; radius: root.r
        opacity: 1 - root.liquidMix
        gradient: Gradient {
            GradientStop { position: 0; color: root.refraction ? Theme.alpha(root.tint,root.glassEnabled ? root.tintOpacity : 1) : Theme.alpha(Theme.mix(root.tint,Qt.rgba(1,1,1,1),Theme.dark ? 0.22 : 0.44),0.64) }
            GradientStop { position: 0.48; color: root.refraction ? Theme.alpha(root.tint,root.glassEnabled ? root.tintOpacity : 1) : Theme.alpha(Theme.mix(root.tint,Theme.accent,0.08),0.48) }
            GradientStop { position: 1; color: root.refraction ? Theme.alpha(root.tint,root.glassEnabled ? root.tintOpacity : 1) : Theme.alpha(Theme.mix(root.tint,Qt.rgba(1,1,1,1),Theme.dark ? 0.10 : 0.3),0.58) }
        }
        border.width: root.refraction ? 0 : 1
        border.color: Theme.alpha(Theme.mix(Theme.accent,Qt.rgba(1,1,1,1),0.6),Theme.dark ? 0.36 : 0.65)
    }
    Rectangle { anchors.fill: parent; anchors.margins: 1.5; radius: Math.max(0,root.r-1.5); color: "transparent"; visible: !root.refraction; border.width: 0.5; border.color: Qt.rgba(1,1,1,Theme.dark ? 0.08 : 0.34) }
    CompositorGlass {
        id: compositor
        anchors.fill: parent
        target: root.compositorTarget
        discoverWhileHidden: target === "launcher-noblur"
        active: root.useCompositor && root.refraction && root.glassEnabled && root.options.screenCapture
        radius: root.r
        prism: root.options.style === "prism"
        bezel: root.bezel; thickness: root.options.thickness * root.refractionAmount
        ior: root.options.ior; dispersion: root.options.dispersion; frost: root.options.frost
        innerShadow: root.innerShadow
        rim: root.rim ? root.options.rimStrength : 0
    }
    NativeGlass {
        id: glass
        objectName: "glass-preview-optics"
        anchors.fill: parent; visible: root.refraction && root.glassEnabled && root.options.screenCapture && root.texture !== null && !compositor.ready
        // Keep one nearly transparent draw while the shader is prepared. The
        // fallback stays underneath until the replacement is ready to blend in.
        opacity: Math.max(0.01, root.liquidMix)
        src: root.texture
        sourceRect: root.textureRect

        topLeftRadius: root.r; topRightRadius: root.r; bottomLeftRadius: root.r; bottomRightRadius: root.r
        tintColor: root.tint; tintAmount: 0 // The shared veil below applies configured opacity once.
        prism: root.options.style === "prism" ? 1 : 0
        bezel: root.bezel
        thickness: root.options.thickness * root.refractionAmount
        ior: root.options.ior; dispersion: root.options.dispersion * root.refractionAmount
        frost: Math.max(0, root.options.frost / 5); rim: root.rim ? root.options.rimStrength : 0
        innerShadow: root.innerShadow
    }
    Rectangle {
        objectName: "glass-preview-veil"
        anchors.fill: parent
        radius: root.r
        visible: glass.visible || compositor.ready
        color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 1); opacity: root.tintOpacity * root.liquidMix
    }
    LiquidGlass {
        anchors.fill: parent
        visible: options.liquidGlass && !compositor.ready && root.glassEnabled
        opacity: 0.35
        blendRadius: options.liquidBlendRadius
        tint: root.tint
        z: -1
    }
    // The optical provider draws the rim; avoid a second flat outline.
}
