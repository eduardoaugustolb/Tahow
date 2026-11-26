//@ pragma UseQApplication
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    readonly property var messages: JSON.parse(catalog.text() || "{}")
    function tr(key) { return messages[key] || key; }
    FileView {
        id: catalog
        path: Quickshell.shellDir + "/../../locales/" + (Qt.locale().name.startsWith("pt") ? "pt-BR" : "en-US") + ".json"
        blockLoading: true
    }

    Window {
        id: win
        visible: true
        visibility: Window.FullScreen
        color: "#101d2b"
        title: "Tahow"
        property string promptStyle: ""
        property string prompt: ""
        property string status: ""
        property bool completed: false

        function submit() {
            if (!client.running) {
                if (!username.text.trim()) return;
                status = "";
                client.running = true;
            } else if (promptStyle) {
                client.write(JSON.stringify(answer.text) + "\n");
                answer.clear();
                promptStyle = "";
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#284e69" }
                GradientStop { position: 1; color: "#101d2b" }
            }
        }
        SystemClock { id: clock; precision: SystemClock.Minutes }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.11
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                color: "white"
                font.pixelSize: Math.min(win.width * 0.11, 124)
                font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                color: "white"
                font.pixelSize: 19
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 360)
            height: form.implicitHeight + 48
            radius: 24
            color: "#ed152131"
            border.color: "#51ffffff"
            Column {
                id: form
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                Label {
                    text: root.tr("User")
                    color: "#f4f8ff"
                }
                TextField {
                    id: username
                    width: parent.width
                    enabled: !client.running
                    focus: true
                    Accessible.name: root.tr("User")
                    onAccepted: win.submit()
                }
                Label {
                    width: parent.width
                    visible: !!win.promptStyle
                    text: win.prompt
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: "#f4f8ff"
                }
                TextField {
                    id: answer
                    width: parent.width
                    visible: !!win.promptStyle
                    echoMode: win.promptStyle === "secret" ? TextInput.Password : TextInput.Normal
                    inputMethodHints: win.promptStyle === "secret" ? Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
                    Accessible.name: win.prompt
                    onAccepted: win.submit()
                }
                Label {
                    width: parent.width
                    visible: !!win.status
                    color: "#f4f8ff"
                    text: win.status
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
                Row {
                    spacing: 8
                    Button {
                        text: root.tr("Continue")
                        enabled: client.running ? !!win.promptStyle : !!username.text.trim()
                        onClicked: win.submit()
                    }
                    Button {
                        text: root.tr("Cancel")
                        visible: !!win.promptStyle
                        onClicked: {
                            answer.clear();
                            win.promptStyle = "";
                            client.write("null\n");
                        }
                    }
                }
            }
        }
        Process {
            id: client
            command: [Quickshell.env("TAHOW_GREETER_BUN"), Quickshell.shellDir + "/client.ts", Quickshell.env("TAHOW_LOGIN_SESSION")]
            stdinEnabled: true
            onStarted: write(JSON.stringify(username.text.trim()) + "\n")
            onExited: (exitCode) => {
                win.promptStyle = "";
                answer.clear();
                if (!win.completed && exitCode !== 0) win.status = root.tr("Login service unavailable");
                username.forceActiveFocus();
            }
            stdout: SplitParser {
                onRead: line => {
                    const reply = JSON.parse(line);
                    switch (reply.type) {
                    case "secret":
                    case "visible":
                        win.prompt = reply.message;
                        win.promptStyle = reply.type;
                        answer.forceActiveFocus();
                        break;
                    case "info":
                    case "error":
                        win.status = reply.message;
                        break;
                    case "started":
                        win.completed = true;
                        Qt.quit();
                        break;
                    case "denied":
                        win.status = root.tr("Login Failed");
                        break;
                    case "unavailable":
                        win.status = root.tr("Login service unavailable");
                        break;
                    }
                }
            }
        }
    }
}
