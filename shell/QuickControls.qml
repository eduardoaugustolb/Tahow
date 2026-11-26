pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    required property var entries
    required property var controls
    Layout.fillWidth: true
    visible: entries.length > 0
    spacing: 0

    Repeater {
        model: root.entries
        delegate: CCButton {
            required property var modelData
            readonly property var control: root.controls[modelData.id]
            Layout.fillWidth: true
            icon: control.icon
            label: control.label
            sub: control.sub || ""
            active: control.active === true
            activeColor: control.tint || Theme.accent
            onClicked: control.run()
        }
    }
}
