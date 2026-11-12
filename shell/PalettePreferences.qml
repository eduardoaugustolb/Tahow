import QtQuick
import QtQuick.Controls
Rectangle {
    required property var launcher
    signal dismissed()
    color: Theme.window; radius: 18
    Column { anchors.centerIn: parent; spacing: 16
        Label { text: I18n.tr("All Tahoe components share one preferences file"); color: Theme.fg }
        Button { text: I18n.tr("Open preferences"); onClicked: { Hub.openSettings(); dismissed(); } }
        Button { text: I18n.tr("Done"); onClicked: dismissed() }
    }
}
