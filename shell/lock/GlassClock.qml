import QtQuick

Item {
    id: root
    required property var backdrop
    required property Item scene
    required property string text
    property real s: 1
    width: glyph.implicitWidth + 8 * s
    height: glyph.implicitHeight + 8 * s
    Text {
        id: glyph
        anchors.centerIn: parent
        text: I18n.tr(root.text)
        font.family: "Inter"; font.weight: Font.DemiBold
        font.pixelSize: 134 * root.s; font.letterSpacing: -7 * root.s
        color: "white"
    }
    ShaderEffectSource {
        id: maskTexture; sourceItem: glyph
        hideSource: true; live: root.visible; visible: false
        sourceRect: Qt.rect(-4 * root.s, -4 * root.s, root.width, root.height)
    }
    ShaderEffect {
        anchors.fill: parent
        property var backdrop: root.backdrop
        property var glyphs: maskTexture
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector4d sourceRect: {
            const pos = mapToItem(root.scene, 0, 0)
            return Qt.vector4d(pos.x / root.scene.width, pos.y / root.scene.height, width / root.scene.width, height / root.scene.height)
        }
        property real strength: 30 * root.s
        fragmentShader: Qt.resolvedUrl("shaders/glass_clock.frag.qsb")
    }
}
