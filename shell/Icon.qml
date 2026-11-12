import QtQuick
import "lib/symbols.js" as Symbols
Item {
    id: root
    property string text: ""
    property real size: 18
    property real fill: 0
    property int weight: 500
    property color color: Theme.fg
    implicitWidth: size; implicitHeight: size
    Image { anchors.fill: parent; visible: Symbols.has(root.text); sourceSize: Qt.size(root.size * 2, root.size * 2); source: Symbols.image(root.text, root.fill > 0, root.color.toString()); smooth: true }
    Text { anchors.centerIn: parent; visible: !Symbols.has(root.text); text: root.text; color: root.color; font.family: Theme.iconFont; font.pixelSize: root.size }
}
