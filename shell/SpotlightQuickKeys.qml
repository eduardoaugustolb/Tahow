import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8
    property bool invalidKey: false

    RowLayout {
        Layout.fillWidth: true
        Txt {
            Layout.fillWidth: true
            sourceText: "Quick Keys"
            weight: Font.DemiBold
        }
        SettingsControls.Button {
            text: I18n.tr("Restore default Quick Keys")
            onClicked: {
                root.invalidKey = false;
                Config.inheritKeys("palette", ["quickKeys"]);
            }
        }
    }

    Repeater {
        model: SpotlightActions.entries
        delegate: RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true

            Txt {
                Layout.fillWidth: true
                text: row.modelData.name
            }
            SettingsControls.Field {
                id: field
                Layout.preferredWidth: 110
                Accessible.name: row.modelData.name
                text: row.modelData.quickKey
                maximumLength: 12
                onEditingFinished: {
                    root.invalidKey = !SpotlightActions.setKey(row.modelData.actionId, text);
                    text = Qt.binding(() => row.modelData.quickKey);
                }
            }
        }
    }

    Txt {
        Layout.fillWidth: true
        visible: root.invalidKey
        sourceText: "Use a unique Quick Key with 1–12 letters (A–Z) or digits."
        wrapMode: Text.WordWrap
    }
}
