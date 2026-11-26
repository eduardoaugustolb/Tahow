import ".." as Tahow
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    spacing: 10

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property int monthOffset: 0
    property date selection: clock.date
    readonly property date monthDate: new Date(clock.date.getFullYear(), clock.date.getMonth() + monthOffset, 1, 12)
    readonly property Tahow.SettingsControls.Colors tones: Tahow.SettingsControls.Colors {}

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Basic.Label {
            Layout.fillWidth: true
            text: Tahow.I18n.locale.standaloneMonthName(root.monthDate.getMonth()) + " " + root.monthDate.getFullYear()
            color: root.tones.windowText
            font.family: Tahow.Theme.font
            font.pixelSize: 20
            font.weight: Font.DemiBold
            Accessible.role: Accessible.Heading
        }

        Tahow.SettingsControls.Button {
            text: Tahow.I18n.tr("Today")
            onClicked: {
                root.monthOffset = 0;
                root.selection = clock.date;
            }
        }

        Tahow.SettingsControls.Button {
            text: "‹"
            Accessible.name: Tahow.I18n.tr("Previous month")
            onClicked: root.monthOffset--
        }

        Tahow.SettingsControls.Button {
            text: "›"
            Accessible.name: Tahow.I18n.tr("Next month")
            onClicked: root.monthOffset++
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: Tahow.I18n.locale
        delegate: Basic.Label {
            required property var model
            text: model.shortName
            horizontalAlignment: Text.AlignHCenter
            color: root.tones.placeholderText
            font.family: Tahow.Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    MonthGrid {
        id: grid
        Layout.fillWidth: true
        Layout.fillHeight: true
        month: root.monthDate.getMonth()
        year: root.monthDate.getFullYear()
        locale: Tahow.I18n.locale
        spacing: 4

        delegate: Basic.Button {
            id: day
            required property var model
            readonly property bool selected: model.year === root.selection.getFullYear()
                && model.month === root.selection.getMonth() && model.day === root.selection.getDate()
            enabled: model.month === grid.month
            focusPolicy: enabled ? Qt.StrongFocus : Qt.NoFocus
            text: String(model.day)
            Accessible.name: model.date.toLocaleDateString(Tahow.I18n.locale, Locale.LongFormat)
            onClicked: root.selection = new Date(model.year, model.month, model.day, 12)

            contentItem: Basic.Label {
                text: day.text
                color: day.selected ? root.tones.highlightedText : day.enabled ? root.tones.windowText : root.tones.placeholderText
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Tahow.Theme.font
                font.pixelSize: 15
                font.weight: day.selected || day.model.today ? Font.DemiBold : Font.Normal
                opacity: day.enabled ? 1 : 0.48
            }

            background: Rectangle {
                radius: 9
                color: day.selected ? root.tones.highlight : day.hovered && day.enabled
                    ? Tahow.Theme.alpha(root.tones.highlight, 0.14) : root.tones.base
                border.width: day.visualFocus ? 2 : day.model.today ? 1 : 0
                border.color: day.visualFocus && day.selected ? root.tones.highlightedText : root.tones.highlight
            }
        }
    }

    Basic.Label {
        Layout.fillWidth: true
        text: root.selection.toLocaleDateString(Tahow.I18n.locale, Locale.LongFormat)
        color: root.tones.placeholderText
        font.family: Tahow.Theme.font
        font.pixelSize: 13
    }
}
