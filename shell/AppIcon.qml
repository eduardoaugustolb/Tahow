import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Squircle app icon with a glyph fallback.
Item {
    id: root
    property string source: ""
    property string fallback: "notifications"
    property color fallbackColor: Theme.accent
    property color styleInk: Theme.fg
    property real size: 38
    property bool styleEnabled: false
    readonly property string style: styleEnabled && ["dark", "clear", "tinted"].includes(Config.general.iconStyle)
        ? Config.general.iconStyle : "default"
    readonly property bool translucentStyle: style === "clear" || style === "tinted"
    readonly property color styleTone: style === "tinted" ? fallbackColor : styleInk
    implicitWidth: size
    implicitHeight: size

    readonly property bool ok: img.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.24
        visible: root.ok && (root.style === "dark" || root.translucentStyle)
        color: root.style === "dark" ? "#22262d" : Theme.alpha(root.styleTone, 0.14)
        border.color: Theme.alpha(root.styleTone, 0.28)
    }
    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.24
        visible: !root.ok
        border.color: root.style === "default" ? "transparent" : Theme.alpha(root.styleTone, 0.28)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.translucentStyle ? Theme.alpha(root.styleTone, 0.20)
                    : root.style === "dark" ? "#303743" : Qt.lighter(root.fallbackColor, 1.15)
            }
            GradientStop {
                position: 1
                color: root.translucentStyle ? Theme.alpha(root.styleTone, 0.10)
                    : root.style === "dark" ? "#1a1f28" : Qt.darker(root.fallbackColor, 1.15)
            }
        }
        Icon {
            anchors.centerIn: parent
            text: root.fallback
            fill: 1
            size: root.size * 0.55
            color: root.translucentStyle ? root.styleTone : root.style === "dark" ? "#dbe2ee" : "#ffffff"
        }
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: root.size * 0.24
        color: "transparent"
        visible: root.ok
        Image {
            id: img
            anchors.fill: parent
            anchors.margins: root.style === "default" ? 0 : Math.round(root.size * 0.14)
            source: root.source
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            layer.enabled: root.style !== "default"
            layer.effect: MultiEffect {
                saturation: root.style === "dark" ? -0.3 : 0
                brightness: root.style === "dark" ? -0.08 : 0
                colorization: root.translucentStyle ? 1 : 0
                colorizationColor: root.styleTone
            }
        }
    }
}
