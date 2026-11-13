import QtQuick
import Quickshell

Item {
    id: root
    property real phase: 0
    readonly property string assetRoot: Quickshell.env("TAHOW_BANNER_ROOT")
    // Align visible artwork, excluding transparent logo margins and the
    // Sacramento font's ascender/descender space.
    readonly property real logoScale: symbol.width / 1254
    readonly property rect logoInk: Qt.rect(148, 251, 996, 876)
    readonly property real gap: root.width * .055
    readonly property real lockupWidth: logoInk.width * logoScale + gap + wordMetrics.tightBoundingRect.width
    readonly property real lockupLeft: (root.width - lockupWidth) / 2
    TextMetrics { id: wordMetrics; font: wordmark.font; text: wordmark.text }
    FontLoader { id: signature; source: root.assetRoot + "/shell/reload/fonts/Sacramento-Regular.ttf" }
    Image {
        id: background
        anchors.fill: parent
        source: root.assetRoot + "/shell/reload/assets/tahow-glass-orbit.png"
        fillMode: Image.Stretch
    }
    ShaderEffectSource { id: wallpaperTexture; sourceItem: background; hideSource: true; live: true; visible: false }
    ShaderEffect {
        id: flowingGlass
        anchors.fill: parent
        property var wallpaper: wallpaperTexture
        property real phase: root.phase
        fragmentShader: root.assetRoot + "/shell/reload/shaders/flow.frag.qsb"
    }
    ShaderEffectSource { id: backdropTexture; sourceItem: flowingGlass; visible: false; live: true }
    Image {
        id: symbol
        x: root.lockupLeft - root.logoInk.x * root.logoScale
        y: root.height / 2 - (root.logoInk.y + root.logoInk.height / 2) * root.logoScale
        width: root.width * .245; height: width
        source: root.assetRoot + "/docs/brand/tahow-logo-concept-v3.png"
        fillMode: Image.PreserveAspectFit
    }
    ShaderEffectSource { id: symbolTexture; sourceItem: symbol; hideSource: true; live: true; visible: false }
    ShaderEffect {
        x: symbol.x; y: symbol.y; width: symbol.width; height: symbol.height
        property var logo: symbolTexture
        property real phase: root.phase
        fragmentShader: root.assetRoot + "/shell/reload/shaders/logo-flow.frag.qsb"
    }
    Text {
        id: wordmark
        x: root.lockupLeft + root.logoInk.width * root.logoScale + root.gap - padding - wordMetrics.tightBoundingRect.x
        y: root.height / 2 - baselineOffset - wordMetrics.tightBoundingRect.y - wordMetrics.tightBoundingRect.height / 2
        text: "Tahow"
        font.family: signature.name
        font.pixelSize: root.width * .17
        color: "white"
        style: Text.Outline; styleColor: "white"
        padding: root.width * .015
    }
    ShaderEffectSource { id: glyphTexture; sourceItem: wordmark; hideSource: true; visible: false; live: true }
    ShaderEffect {
        x: wordmark.x; y: wordmark.y; width: wordmark.width; height: wordmark.height
        property var backdrop: backdropTexture
        property var glyphs: glyphTexture
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: Qt.vector4d(x/root.width, y/root.height, width/root.width, height/root.height)
        property real phase: root.phase
        fragmentShader: root.assetRoot + "/shell/reload/shaders/welcome.frag.qsb"
    }
}
