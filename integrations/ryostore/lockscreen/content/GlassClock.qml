import QtQuick

Item {
    id: root
    required property string text
    property real s: 1
    width: glyph.implicitWidth + 8 * s
    height: glyph.implicitHeight + 8 * s
    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.text
        font.family: "Inter"; font.weight: Font.DemiBold
        font.pixelSize: 134 * root.s; font.letterSpacing: -7 * root.s
        color: "white"
    }
}
