import QtQuick
import "liquid"

// Liquid-glass surface built on the true-liquid-glass (shojiwm) smooth-min
// silhouette engine. Renders one or more LiquidShapes merged into a single
// antialiased glass layer. Configure blendRadius and tint; pass a list of
// LiquidShape objects via `shapes` for compound silhouettes.
Item {
    id: root

    property real blendRadius: Config.general.liquidBlendRadius
    property color tint: Theme.glassTint
    property real opacityValue: 1
    property list<LiquidShape> shapes: [
        LiquidShape {
            x: 0
            y: 0
            width: root.width
            height: root.height
            radius: Math.min(root.width, root.height) / 2
            presence: 1
        }
    ]

    LiquidGroup {
        anchors.fill: parent
        blendRadius: root.blendRadius
        tint: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tint.a * root.opacityValue)
        shapes: root.shapes
    }
}
