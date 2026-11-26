import QtQuick
import QtQuick.Layouts
import "lib/focus.js" as Focus

Column {
    id: root
    spacing: 6

    readonly property var schedule: Config.island.focusSchedule
    readonly property bool validSchedule: (!start.text && !end.text)
        || (Focus.minutes(start.text) >= 0 && Focus.minutes(end.text) >= 0 && start.text !== end.text)

    RowLayout {
        width: root.width
        SettingsControls.Toggle {
            text: I18n.tr("Do Not Disturb")
            checked: Notifs.dnd
            onToggled: Notifs.toggleDnd()
        }
        Item { Layout.fillWidth: true }
        SettingsControls.Button {
            text: I18n.tr("Enable for one hour")
            onClicked: Notifs.focusForHour()
        }
    }
    Txt { sourceText: "Daily Focus schedule" }
    RowLayout {
        width: root.width
        SettingsControls.Field {
            id: start
            Layout.fillWidth: true
            placeholderText: I18n.tr("Start (HH:MM)")
            Accessible.name: placeholderText
            text: typeof root.schedule?.start === "string" ? root.schedule.start : ""
            maximumLength: 5
        }
        SettingsControls.Field {
            id: end
            Layout.fillWidth: true
            placeholderText: I18n.tr("End (HH:MM)")
            Accessible.name: placeholderText
            text: typeof root.schedule?.end === "string" ? root.schedule.end : ""
            maximumLength: 5
        }
        SettingsControls.Button {
            text: I18n.tr("Apply schedule")
            enabled: root.validSchedule
            onClicked: Config.set("island", "focusSchedule", start.text ? {start: start.text, end: end.text} : {})
        }
    }
    Txt {
        width: root.width
        sourceText: "Use two different 24-hour times. Leave both blank to disable the schedule."
        wrapMode: Text.WordWrap
    }
    Txt { sourceText: "Apps allowed during Focus" }
    SettingsControls.Field {
        width: root.width
        Accessible.name: I18n.tr("Apps allowed during Focus")
        placeholderText: I18n.tr("App names or desktop IDs, separated by commas")
        text: Config.island.focusAllowedApps
        onEditingFinished: Config.set("island", "focusAllowedApps", text.trim())
    }
}
