import ".." as Tahow
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: window
    signal dismissed()
    property alias body: content.sourceComponent

    visible: true
    color: "transparent"
    minimumWidth: 440
    minimumHeight: 360
    onVisibleChanged: if (!visible) dismissed()

    readonly property Tahow.SettingsControls.Colors tones: Tahow.SettingsControls.Colors {}

    Shortcut { sequences: [StandardKey.Close]; onActivated: window.close() }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: window.tones.window
        border.color: Tahow.Theme.alpha(window.tones.mid, 0.55)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Basic.Label {
                Layout.fillWidth: true
                text: window.title
                color: window.tones.windowText
                font.family: Tahow.Theme.font
                font.pixelSize: 23
                font.weight: Font.DemiBold
                Accessible.role: Accessible.Heading
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Tahow.Theme.alpha(window.tones.mid, 0.55)
            }

            Loader {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
