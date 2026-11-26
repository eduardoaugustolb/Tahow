import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".." as Tahow

Column {
    id: root
    property bool keyboard: false
    readonly property bool available: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property color ink: paletteProbe.palette.windowText
    spacing: 10

    Label {
        id: paletteProbe
        width: parent.width
        color: root.ink
        wrapMode: Text.WordWrap
        text: Tahow.I18n.tr(root.available ? "Input changes apply to this Hyprland session." : "Input controls require a Hyprland session.")
    }

    Repeater {
        model: !root.available ? [] : root.keyboard ? [
            {key: "kb_layout", label: "Keyboard layout", field: "str"},
            {key: "repeat_rate", label: "Key repeat rate", field: "int", min: 1, max: 100},
            {key: "repeat_delay", label: "Key repeat delay (ms)", field: "int", min: 100, max: 2000}
        ] : [
            {key: "sensitivity", label: "Pointer speed", field: "float", min: -1, max: 1},
            {key: "natural_scroll", label: "Natural scrolling", field: "bool"}
        ]

        Row {
            id: row
            required property var modelData
            width: root.width
            height: 40
            property string current: ""
            property bool ready: false
            property bool failed: false
            property string pending: ""
            function apply(value) {
                if (!ready || readOption.running || writeOption.running) return;
                pending = value;
                writeOption.running = true;
            }
            Process {
                id: readOption
                command: ["hyprctl", "-j", "getoption", "input:" + row.modelData.key]
                Component.onCompleted: running = true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const data = JSON.parse(text);
                            const value = data[row.modelData.field === "bool" ? "int" : row.modelData.field];
                            if (value === undefined) throw new Error("Missing input option");
                            row.current = String(value);
                            row.ready = true;
                        } catch (_) { row.failed = true; }
                    }
                }
            }
            Process {
                id: writeOption
                command: ["hyprctl", "keyword", "input:" + row.modelData.key, row.pending]
                stdout: StdioCollector {
                    onStreamFinished: {
                        row.failed = text.trim() !== "ok";
                        if (!row.failed) row.current = row.pending;
                        editor.text = row.current;
                    }
                }
            }
            Label {
                width: parent.width - 155
                anchors.verticalCenter: parent.verticalCenter
                color: root.ink
                text: Tahow.I18n.tr(row.modelData.label) + (row.failed ? " · " + Tahow.I18n.tr("Unavailable") : "")
            }
            Tahow.SettingsControls.Toggle {
                visible: row.modelData.field === "bool"
                enabled: row.ready && !writeOption.running
                checked: row.current === "1"
                Accessible.name: Tahow.I18n.tr(row.modelData.label)
                onToggled: {
                    row.apply(checked ? "1" : "0");
                    checked = Qt.binding(() => row.current === "1");
                }
            }
            Tahow.SettingsControls.Field {
                id: editor
                visible: row.modelData.field !== "bool"
                enabled: row.ready && !writeOption.running
                width: 145
                text: row.current
                Accessible.name: Tahow.I18n.tr(row.modelData.label)
                onEditingFinished: {
                    const value = text.trim();
                    const number = Number(value);
                    const valid = row.modelData.field === "str" ? /^[a-zA-Z0-9_-]+(,[a-zA-Z0-9_-]+)*$/.test(value)
                        : value !== "" && number >= row.modelData.min && number <= row.modelData.max
                            && (row.modelData.field !== "int" || Number.isInteger(number));
                    if (valid && value !== row.current) row.apply(row.modelData.field === "str" ? value : String(number));
                    else text = row.current;
                }
            }
        }
    }
}
