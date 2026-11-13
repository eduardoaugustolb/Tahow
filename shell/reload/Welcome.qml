import QtQuick

Item {
    id: root
    property url wallpaper: Qt.resolvedUrl("assets/tahow-glass-orbit.png")
    property real phase: 0
    property string word: "welcome"
    FontLoader { id: scriptFont; source: "fonts/Sacramento-Regular.ttf" }
    Image { id: background; anchors.fill: parent; source: root.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: false }
    ShaderEffectSource { id: wallpaperTexture; sourceItem: background; hideSource: true; live: true; visible: false }
    ShaderEffect {
        id: liquidBackground
        anchors.fill: parent
        property var wallpaper: wallpaperTexture
        property real phase: root.phase
        fragmentShader: Qt.resolvedUrl("shaders/flow.frag.qsb")
    }
    ShaderEffectSource { id: backgroundTexture; sourceItem: liquidBackground; live: true; visible: false }
    Text {
        id: letters
        anchors.centerIn: parent
        text: root.word
        font.family: scriptFont.name
        font.pixelSize: root.width * 0.25
        style: Text.Outline
        styleColor: "white"
        color: "white"
        padding: root.width * 0.015
    }
    ShaderEffectSource { id: mask; sourceItem: letters; hideSource: true; visible: false; live: true }
    ShaderEffect {
        x: letters.x; y: letters.y; width: letters.width; height: letters.height
        property var backdrop: backgroundTexture
        property var glyphs: mask
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: Qt.vector4d(x / root.width, y / root.height, width / root.width, height / root.height)
        property real phase: root.phase
        fragmentShader: Qt.resolvedUrl("shaders/welcome.frag.qsb")
    }
}
