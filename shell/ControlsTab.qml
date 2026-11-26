pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "lib/control-center.js" as ControlCenter

// Control Center: connectivity module (with Wi-Fi / Bluetooth menus), big sliders,
// toggles and power. Active toggles take your theme accent (Settings → Controls).
Item {
    id: root
    clip: true

    readonly property var controlLayout: ControlCenter.normalize(Config.island.ccLayout)
    readonly property var pinnedControls: ControlCenter.visibleControls(controlLayout, true)
    readonly property var unpinnedControls: ControlCenter.visibleControls(controlLayout, false)
    readonly property var controls: ({
        "night-shift": { icon: "nightlight", label: "Night Shift", sub: Hub.nightLight ? Config.island.nightLightTemp + "K" : "Off", active: Hub.nightLight, tint: Theme.ccTint("#ff9f45"), run: () => Hub.nightLight = !Hub.nightLight },
        "caffeine": { icon: "coffee", label: "Caffeine", sub: Hub.caffeine ? "Awake" : "Off", active: Hub.caffeine, tint: Theme.ccTint(Theme.orange), run: () => Hub.caffeine = !Hub.caffeine },
        "timer": { icon: "timer", label: "Timer", sub: Hub.timerActive ? Hub.fmtTime(Hub.timerLeft) : "25 min", active: Hub.timerActive, tint: Theme.ccTint(Theme.orange), run: () => Hub.timerActive ? Hub.timerToggle() : Hub.startTimer(1500) },
        "mic": { icon: Hub.micMuted ? "mic_off" : "mic", label: "Mic", sub: Hub.micMuted ? "Muted" : "Live", active: Hub.micMuted, tint: Theme.red, run: () => Hub.toggleMic() },
        "screenshot": { icon: "screenshot_region", label: "Screenshot", run: () => Hub.screenshot() },
        "colour": { icon: "colorize", label: "Colour", run: () => Hub.colorPick() },
        "settings": { icon: "settings", label: "Settings", run: () => Hub.openSettings() }
    })

    function updateControl(index, changes) {
        const layout = controlLayout.slice();
        layout[index] = Object.assign({}, layout[index], changes);
        Config.set("island", "ccLayout", layout);
    }

    function moveControl(index, offset) {
        Config.set("island", "ccLayout", ControlCenter.move(controlLayout, index, offset));
    }

    component PowerBtn: Rectangle {
        id: pb
        property string icon: ""
        property string label: ""
        property bool confirm: Config.island.confirmPower
        property color armColor: Theme.red
        property bool armed: false
        signal triggered()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 20
        color: armed ? armColor : pbMa.containsMouse ? Theme.fill2 : Theme.fill
        scale: pbMa.pressed ? 0.94 : 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Icon { text: pb.armed ? "check" : pb.icon; size: 17; fill: pb.armed ? 1 : 0; color: pb.armed ? "#ffffff" : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
            Txt { sourceText: pb.armed ? "Confirm" : pb.label; size: 12; weight: Font.DemiBold; color: pb.armed ? "#ffffff" : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
        }
        Timer { id: disarm; interval: 2600; onTriggered: pb.armed = false }
        MouseArea {
            id: pbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pb.confirm && !pb.armed) { pb.armed = true; disarm.restart(); return; }
                pb.armed = false;
                pb.triggered();
            }
        }
    }

    // ═══════════════════════ MAIN PAGE ═══════════════════════
    Item {
        id: main
        width: root.width
        height: root.height
        readonly property bool shown: Hub.ccPage === ""
        x: shown ? 0 : -root.width * 0.3
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        enabled: shown
        Behavior on x { NumberAnimation { duration: Theme.reduced ? 1 : 380; easing.type: Config.island.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 240 } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            QuickControls { entries: root.pinnedControls; controls: root.controls }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 164
                spacing: 12

                ColumnLayout {
                    Layout.preferredWidth: 248
                    Layout.maximumWidth: 248
                    Layout.fillHeight: true
                    spacing: 8
                    CCPill {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: Hub.wifiOn ? "wifi" : "wifi_off"
                        label: "Wi-Fi"
                        sub: Hub.wifiSub
                        active: Hub.wifiOn
                        activeColor: Theme.ccTint(Theme.blue)
                        onToggled: Hub.toggleWifi()
                        onOpened: Hub.ccPage = "wifi"
                    }
                    CCPill {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: Hub.btOn ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        sub: Hub.btAdapter ? Hub.btSub : "Unavailable"
                        active: Hub.btOn
                        activeColor: Theme.ccTint(Theme.blue)
                        onToggled: Hub.toggleBt()
                        onOpened: Hub.ccPage = "bt"
                    }
                    CCPill {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        icon: "bedtime"
                        label: "Focus"
                        sub: Notifs.dnd ? "Do Not Disturb" : "Off"
                        active: Notifs.dnd
                        activeColor: Theme.ccTint(Theme.indigo)
                        hasMenu: false
                        onToggled: Notifs.toggleDnd()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    Widget {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        pad: 10
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Txt { sourceText: "Sound"; size: 11; weight: Font.DemiBold; color: Theme.fg2 }
                                Item { Layout.fillWidth: true }
                                Icon { text: Hub.sinkIcon(); size: 14; fill: 1; color: Theme.fg2 }
                                Txt { sourceText: Hub.sinkName; size: 11; color: Theme.fg2; Layout.maximumWidth: 240 }
                            }
                            SliderBar {
                                Layout.fillWidth: true
                                big: true
                                barHeight: 38
                                icon: Hub.volumeIcon
                                value: Hub.muted ? 0 : Hub.volume
                                color: Config.island.ccAccent ? Theme.accent : "#ffffff"
                                onMoved: v => Hub.setVolume(v)
                            }
                        }
                    }
                    Widget {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        pad: 10
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4
                            Txt {
                                sourceText: Hub.hasBacklight ? "Display" : "Microphone"
                                size: 11; weight: Font.DemiBold; color: Theme.fg2
                            }
                            SliderBar {
                                visible: Hub.hasBacklight
                                Layout.fillWidth: true
                                big: true
                                barHeight: 38
                                icon: "light_mode"
                                value: Hub.brightness
                                color: Config.island.ccAccent ? Theme.accent : "#ffffff"
                                onMoved: v => Hub.setBrightness(v)
                            }
                            SliderBar {
                                visible: !Hub.hasBacklight
                                Layout.fillWidth: true
                                big: true
                                barHeight: 38
                                icon: Hub.micMuted ? "mic_off" : "mic"
                                value: Hub.source && Hub.source.audio && !Hub.micMuted ? Hub.source.audio.volume : 0
                                color: Config.island.ccAccent ? Theme.accent : "#ffffff"
                                onMoved: v => { if (Hub.source && Hub.source.audio) { Hub.source.audio.muted = false; Hub.source.audio.volume = v; } }
                            }
                        }
                    }
                }
            }

            QuickControls { entries: root.unpinnedControls; controls: root.controls }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PowerBtn { icon: "lock"; label: "Lock"; confirm: false; onTriggered: Hub.session("lock") }
                PowerBtn { icon: "dark_mode"; label: "Sleep"; armColor: Theme.indigo; onTriggered: Hub.session("suspend") }
                PowerBtn { icon: "logout"; label: "Log Out"; armColor: Theme.orange; onTriggered: Hub.session("logout") }
                PowerBtn { icon: "restart_alt"; label: "Restart"; armColor: Theme.orange; onTriggered: Hub.session("reboot") }
                PowerBtn { icon: "power_settings_new"; label: "Shut Down"; onTriggered: Hub.session("shutdown") }
                SettingsControls.Button {
                    id: editButton
                    text: I18n.tr("Edit Controls")
                    onClicked: Hub.ccPage = "edit"
                }
            }
        }
    }

    // ═══════════════════════ DRILL-DOWN PAGES ═══════════════════════
    component SubPage: Item {
        id: sp
        property string page: ""
        readonly property bool shown: Hub.ccPage === page
        x: shown ? 0 : width
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        enabled: shown
        Behavior on x { NumberAnimation { duration: Theme.reduced ? 1 : 380; easing.type: Config.island.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 240 } }
    }
    SubPage { page: "wifi"; width: root.width; height: root.height; WifiPage { anchors.fill: parent } }
    SubPage { page: "bt"; width: root.width; height: root.height; BluetoothPage { anchors.fill: parent } }
    SubPage {
        page: "edit"
        width: root.width
        height: root.height
        onShownChanged: if (shown) doneButton.forceActiveFocus();
        Keys.onEscapePressed: doneButton.clicked()

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Txt { sourceText: "Edit Controls"; size: 21; weight: Font.Bold; Layout.fillWidth: true }
                SettingsControls.Button {
                    text: I18n.tr("Restore Control Layout")
                    onClicked: Config.set("island", "ccLayout", [])
                }
                SettingsControls.Button {
                    id: doneButton
                    text: I18n.tr("Done")
                    onClicked: {
                        Hub.ccPage = "";
                        editButton.forceActiveFocus();
                    }
                }
            }

            Repeater {
                model: ControlCenter.controlIds.length
                delegate: RowLayout {
                    id: row
                    required property int index
                    readonly property var entry: root.controlLayout[index]
                    readonly property var control: root.controls[entry.id]
                    Layout.fillWidth: true
                    Icon { text: row.control.icon; size: 18 }
                    Txt { sourceText: row.control.label; Layout.fillWidth: true }
                    SettingsControls.Button {
                        text: row.entry.hidden ? I18n.tr("Show Control") : I18n.tr("Hide Control")
                        Accessible.name: text + " · " + I18n.tr(row.control.label)
                        onClicked: root.updateControl(row.index, { hidden: !row.entry.hidden })
                    }
                    SettingsControls.Button {
                        text: row.entry.pinned ? I18n.tr("Unpin Control") : I18n.tr("Pin Control")
                        Accessible.name: text + " · " + I18n.tr(row.control.label)
                        onClicked: root.updateControl(row.index, { pinned: !row.entry.pinned })
                    }
                    SettingsControls.Button {
                        text: I18n.tr("Move Up")
                        Accessible.name: text + " · " + I18n.tr(row.control.label)
                        enabled: row.index > 0
                        onClicked: root.moveControl(row.index, -1)
                    }
                    SettingsControls.Button {
                        text: I18n.tr("Move Down")
                        Accessible.name: text + " · " + I18n.tr(row.control.label)
                        enabled: row.index < root.controlLayout.length - 1
                        onClicked: root.moveControl(row.index, 1)
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
