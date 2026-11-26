import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:tahow-capture"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string mode: ""
    property string filePath: ""
    property bool includeAudio: false
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("bin/capture.sh").toString().replace(/^file:\/\//, ""))
    readonly property bool recording: job.running && mode === "record" && filePath !== ""

    function toggle() {
        if (selection.running) {
            selection.signal(15);
            visible = true;
            panel.forceActiveFocus();
            return "open";
        }
        if (job.running && !recording) return "busy";
        if (!visible && !screen) screen = Quickshell.screens[0] ?? null;
        visible = !visible;
        if (visible) panel.forceActiveFocus();
        return visible ? "open" : "closed";
    }

    function run(action, scope) {
        if (job.running || selection.running) return;
        visible = false;
        mode = action;
        filePath = "";
        if (scope === "region") {
            selection.running = true;
            return;
        }
        startJob(scope, "");
    }

    function startJob(scope, geometry) {
        job.exec(["sh", script, mode, scope, includeAudio ? "audio" : "silent", geometry]);
    }

    Process {
        id: selection
        command: ["sh", root.script, "select"]
        stdout: StdioCollector { id: area }
        onExited: code => {
            const geometry = area.text.trim();
            if (!root.visible && code === 0 && geometry !== "") root.startJob("region", geometry);
        }
    }

    function stop() {
        if (!recording) return;
        visible = false;
        job.signal(2);
    }

    Process {
        id: job
        stdout: SplitParser {
            onRead: line => root.filePath = line
        }
        onExited: (code, status) => {
            if (code === 3) return;
            if (root.mode === "record") {
                Hub.flash("osd", "radio_button_checked", code === 0 ? "Recording Saved" : "Recording failed", -1);
            } else if (root.mode === "screenshot") {
                Hub.flash("osd", "screenshot_region", code === 0 ? "Screenshot saved and copied" : "Screenshot failed", -1);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            if (!panel.contains(panel.mapFromItem(parent, mouse.x, mouse.y))) root.visible = false;
        }
    }

    FocusScope {
        id: panel
        focus: true
        Keys.onEscapePressed: root.visible = false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        width: content.implicitWidth + 36
        height: content.implicitHeight + 36

        Glass {
            anchors.fill: parent
            radius: 25
            compositorTarget: "quickshell:tahow-capture"
            compositorWithoutCapture: true
        }

        Rectangle {
            anchors.fill: parent
            radius: 25
            color: Theme.dark ? "#b51c1c20" : "#d9f3f3f7"
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: 12

            Txt {
                sourceText: root.recording ? "Screen Recording" : "Screen capture"
                size: 16
                weight: Font.DemiBold
            }

            GridLayout {
                rowSpacing: 8
                columnSpacing: 8
                columns: 3
                visible: !root.recording

                CaptureButton { Layout.fillWidth: true; glyph: "screenshot_region"; text: "Capture area"; onClicked: root.run("screenshot", "region") }
                CaptureButton { Layout.fillWidth: true; glyph: "desktop_windows"; text: "Capture screen"; onClicked: root.run("screenshot", "screen") }
                CaptureButton { Layout.fillWidth: true; glyph: "web_asset"; text: "Capture window"; onClicked: root.run("screenshot", "window") }
                CaptureButton { Layout.fillWidth: true; glyph: "radio_button_checked"; recordAction: true; text: "Record area"; onClicked: root.run("record", "region") }
                CaptureButton { Layout.fillWidth: true; glyph: "videocam"; recordAction: true; text: "Record screen"; onClicked: root.run("record", "screen") }
                CaptureButton { Layout.fillWidth: true; glyph: "colorize"; text: "Colour picker"; onClicked: root.run("colour", "screen") }
            }

            CaptureButton {
                visible: !root.recording
                text: "Include audio"
                glyph: checked ? "volume_up" : "volume_off"
                checkable: true
                checked: root.includeAudio
                onToggled: root.includeAudio = checked
            }

            CaptureButton {
                visible: root.recording
                glyph: "stop_circle"
                recordAction: true
                text: "Stop recording"
                onClicked: root.stop()
            }
        }
    }

    component CaptureButton: Button {
        id: button
        property string glyph: ""
        property bool recordAction: false
        hoverEnabled: true
        padding: 12
        implicitHeight: 44
        contentItem: RowLayout {
            spacing: 8
            Icon {
                text: button.glyph
                size: 17
                color: button.recordAction
                    ? (Theme.dark ? "#ff969c" : "#9f1428")
                    : Theme.fg
            }
            Txt {
                Layout.fillWidth: true
                sourceText: button.text
                color: Theme.fg
                size: 13
                weight: Font.DemiBold
            }
        }
        background: Rectangle {
            radius: 12
            color: Theme.dark
                ? (button.down ? "#464650" : button.hovered || button.checked ? "#373740" : "#29292f")
                : (button.down ? "#d7dbe5" : button.hovered || button.checked ? "#e6ebf4" : "#ffffff")
            border.width: button.visualFocus ? 2 : 1
            border.color: button.visualFocus
                ? (Theme.dark ? "#a6ccff" : "#285a9e")
                : (Theme.dark ? "#555561" : "#a0a5b0")
        }
    }

}
