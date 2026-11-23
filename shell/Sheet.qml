import QtQuick
import "lib/backdrop.js" as Backdrop
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "lib/catalog.js" as Catalog

PanelWindow {
    id: sheet
    visible: launcher.shown
    required property var launcher
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher-noblur"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    property bool settingsOpen: false
    property real reveal: 0
    property bool frameReady: false
    property bool captureFailed: false
    function stateDump() { return { provider: material.compositorReady ? "compositor-live" : capture.hasContent ? "snapshot" : "simulated", width: panel.width, height: panel.height, columns: cols, gridWidth: grid.width, cellWidth: grid.cellWidth, frameReady: frameReady, captureHasContent: capture.hasContent, captureFailed: captureFailed, bubble: panel.bubble }; }
    readonly property real targetWidth: Math.min(width - 32, 664)
    readonly property int cols: Math.max(1, Math.min(launcher.columns,
        Math.floor((targetWidth - 36) / 80)))
    readonly property int rowHeight: 80
    readonly property int rows: Math.max(1, Math.min(4, Math.floor((height - 80 - 140) / rowHeight)))
    readonly property color ink: launcher.ink
    readonly property color accent: Theme.accent
    readonly property bool captureAllowed: launcher.glass && !captureFailed && Config.palette.screenCapture
    property bool ownsCapture: false
    readonly property bool readyToReveal: !captureAllowed || frameReady
    Component.onCompleted: {
        if (captureAllowed) { ownsCapture = true; Host.beginCapture(); captureDelay.start(); }
        reveal = Qt.binding(() => launcher.openRequested && readyToReveal ? 1 : 0);
        Qt.callLater(() => { panel.bubble = Qt.binding(() => launcher.openRequested && readyToReveal ? 1 : 0); });
    }
    onFrameReadyChanged: if (frameReady && ownsCapture) { ownsCapture = false; Host.endCapture(); }
    Component.onDestruction: if (ownsCapture) Host.endCapture()
    Timer { id: captureDelay; interval: 64; onTriggered: capture.captureSource = sheet.screen }

    Behavior on reveal { NumberAnimation { duration: sheet.launcher.reduced ? 1 : Config.palette.fastDuration; easing.type: Config.palette.easing } }

    // One frame only. Keep its capture source alive until this sheet is destroyed;
    // clearing it invalidates the texture the native shader is sampling.
    // No whole-output capture is requested on providers without the capability.
    ScreencopyView {
        id: capture
        anchors.fill: parent
        captureSource: null
        live: false
        paintCursor: false
        onHasContentChanged: if (hasContent) sheet.frameReady = true
    }
    ShaderEffectSource {
        id: frozen
        width: sheet.width
        height: sheet.height
        sourceItem: capture
        textureSize: { const s = Backdrop.size(sheet.width, sheet.height); return Qt.size(s.width, s.height); }
        mipmap: true
        // The screencopy already holds one frozen frame. Keep the texture
        // provider live so it uploads when the opening panel starts rendering.
        // Waiting for scheduleUpdate here deadlocks while reveal is zero.
        live: true; hideSource: true; visible: false
    }
    Timer {
        running: sheet.captureAllowed && !sheet.frameReady
        interval: 700
        onTriggered: if (!sheet.frameReady) { sheet.captureFailed = true; if (sheet.ownsCapture) { sheet.ownsCapture = false; Host.endCapture(); } }
    }
    MouseArea { anchors.fill: parent; onClicked: sheet.launcher.hide() }

    Item {
        id: panel
        property real bubble: 0
        transformOrigin: Item.Top
        Behavior on bubble {
            enabled: !sheet.launcher.reduced
            SpringAnimation { spring: sheet.launcher.spring; damping: sheet.launcher.damping; epsilon: 0.001 }
        }
        width: sheet.targetWidth
        height: 140 + sheet.rows * sheet.rowHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Tokens.px(56), (sheet.height - height) * Math.max(0, Math.min(1, Config.palette.palettePosition))) + (1 - bubble) * Tokens.px(-18)
        opacity: sheet.reveal
        scale: sheet.launcher.reduced ? 1 : 0.88 + bubble * 0.12

        Glass {
            id: material
            anchors.fill: parent
            options: Config.palette
            tint: sheet.launcher.tint
            radius: Tokens.px(24)
            shadow: !glassEnabled
            shadowBlur: Tokens.px(36)
            shadowY: Tokens.px(12)
            compositorTarget: "launcher-noblur"
            useCompositor: sheet.captureAllowed
            texture: capture.hasContent ? frozen : null
            textureRect: Qt.rect(panel.x / sheet.width, panel.y / sheet.height, panel.width / sheet.width, panel.height / sheet.height)
            onCompositorAvailableChanged: if (compositorAvailable) {
                captureDelay.stop(); capture.captureSource = null;
                sheet.frameReady = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: material.radius
            color: sheet.launcher.dark ? "#ed1a1c22" : "#edf4f5f8"
        }
        MouseArea { anchors.fill: parent }

        Item {
            id: header
            x: Tokens.px(18); y: Tokens.px(16)
            width: parent.width - x * 2; height: Tokens.px(42)
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: settingsButton.left; rightMargin: 8 }
                radius: 11
                color: Theme.alpha(sheet.ink, 0.07)
                border.color: Theme.alpha(sheet.ink, 0.13)
                MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
            }
            Item {
                id: mark
                x: 13
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 11; height: 11; x: 1; y: 1
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.alpha(sheet.ink, 0.7)
                    border.width: 1.5
                }
                Rectangle {
                    x: 10; y: 9; width: 7; height: 1.5
                    radius: 1; rotation: 45; transformOrigin: Item.Left
                    color: Theme.alpha(sheet.ink, 0.7)
                }
            }
            TextInput {
                id: field
                anchors { left: mark.right; leftMargin: Tokens.px(10); right: settingsButton.left; rightMargin: Tokens.px(18); verticalCenter: parent.verticalCenter }
                focus: true; clip: true
                color: sheet.launcher.ink
                font.family: sheet.launcher.fontFamily
                font.pixelSize: Tokens.px(16)
                selectByMouse: true
                onTextEdited: { sheet.launcher.query = text; sheet.launcher.selected = 0; }
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (sheet.settingsOpen) sheet.settingsOpen = false;
                        else if (text.length) { text = ""; sheet.launcher.query = ""; }
                        else sheet.launcher.hide();
                        break;
                    case Qt.Key_Return: case Qt.Key_Enter: sheet.launcher.launch(sheet.launcher.results[sheet.launcher.selected]); break;
                    case Qt.Key_Down: sheet.launcher.move(sheet.cols); break;
                    case Qt.Key_Up: sheet.launcher.move(-sheet.cols); break;
                    case Qt.Key_Left: if (text.length) return; sheet.launcher.move(-1); break;
                    case Qt.Key_Right: if (text.length) return; sheet.launcher.move(1); break;
                    case Qt.Key_Tab: case Qt.Key_Backtab:
                        const ids = ["all"].concat(Catalog.groups.map(g => g.id));
                        const step = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
                        sheet.launcher.section = ids[(ids.indexOf(sheet.launcher.section) + step + ids.length) % ids.length];
                        sheet.launcher.selected = 0;
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }
                Text {
                    visible: !field.text.length
                    text: I18n.tr("Search applications")
                    color: sheet.launcher.ink; opacity: 0.65
                    font: field.font
                }
            }
            Text {
                id: settingsButton
                width: Tokens.px(38); height: parent.height
                anchors.right: parent.right
                text: I18n.tr("···"); color: sheet.launcher.ink
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                font.pixelSize: Tokens.px(22)
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: sheet.settingsOpen = !sheet.settingsOpen
                }
            }
        }
        Row {
            id: tabs
            x: Tokens.px(18); y: Tokens.px(68)
            width: parent.width - x * 2; height: Tokens.px(29)
            spacing: Tokens.px(5)
            Repeater {
                model: Catalog.groups
                Rectangle {
                    id: tab
                    required property var modelData
                    width: (tabs.width - tabs.spacing * 4) / 5
                    height: tabs.height; radius: Tokens.px(7)
                    readonly property bool active: !sheet.launcher.query && sheet.launcher.section === modelData.id
                    color: active ? Theme.alpha(sheet.accent, 0.2) : Theme.alpha(sheet.ink, tabMouse.containsMouse ? 0.09 : 0)
                    border.color: active ? Theme.alpha(sheet.accent, 0.55) : "transparent"
                    Text {
                        anchors.fill: parent; anchors.margins: Tokens.px(2)
                        text: I18n.tr(tab.modelData.label)
                        color: sheet.launcher.ink
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(12)
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            field.clear();
                            sheet.launcher.query = "";
                            sheet.launcher.section = sheet.launcher.section === tab.modelData.id ? "all" : tab.modelData.id;
                            sheet.launcher.selected = 0;
                            field.forceActiveFocus();
                        }
                    }
                }
            }
        }
        Text {
            id: sectionTitle
            x: Tokens.px(20); y: Tokens.px(103)
            text: I18n.tr(sheet.launcher.query ? "Search results" : "All applications")
            visible: sheet.launcher.query.length > 0 || sheet.launcher.section === "all"
            color: sheet.launcher.ink; opacity: 0.74
            font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(12); font.weight: Font.DemiBold
        }
        GridView {
            id: grid
            y: 121
            anchors.horizontalCenter: parent.horizontalCenter
            cellWidth: Math.floor((panel.width - 36) / sheet.cols)
            cellHeight: sheet.rowHeight
            width: cellWidth * sheet.cols
            height: sheet.rows * cellHeight
            clip: true
            snapMode: GridView.SnapToRow
            model: ScriptModel { values: sheet.launcher.results }
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: sheet.launcher.selected
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
            onCountChanged: Qt.callLater(() => {
                if (sheet.launcher.selected === 0) positionViewAtBeginning();
            })
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: Tokens.px(2)
                    radius: Tokens.px(12)
                    visible: tile.index === sheet.launcher.selected
                    color: Theme.alpha(sheet.accent, 0.15)
                    border.color: Theme.alpha(sheet.accent, 0.50)
                }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 9
                    implicitSize: 40
                    source: Quickshell.iconPath(tile.modelData.icon || "application-x-executable", true)
                    asynchronous: true
                }
                Text {
                    x: 5; y: 55; width: parent.width - x * 2
                    text: I18n.tr(tile.modelData.name)
                    color: sheet.launcher.ink
                    font.family: sheet.launcher.fontFamily; font.pixelSize: 12
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPositionChanged: sheet.launcher.selected = tile.index
                    onClicked: sheet.launcher.launch(tile.modelData)
                }
            }
            ScrollBar.vertical: ScrollBar {
                parent: panel
                x: grid.x + grid.width + 4; y: grid.y
                height: grid.height; width: 8
                policy: ScrollBar.AsNeeded
            }
        }
        Text {
            anchors.centerIn: grid
            visible: !sheet.launcher.results.length
            text: I18n.tr("No applications found")
            color: sheet.launcher.ink
            font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(13)
        }
        Text {
            id: footer
            anchors { bottom: parent.bottom; bottomMargin: Tokens.px(4); left: parent.left; leftMargin: Tokens.px(18) }
            text: I18n.tr("↑↓←→ Navigate   ↵ Open   ⇥ Category   Esc Close")
            color: sheet.launcher.ink; opacity: 0.67
            font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(10)
        }
        PalettePreferences {
            anchors.fill: parent; anchors.margins: Tokens.px(8)
            visible: sheet.settingsOpen
            launcher: sheet.launcher
            onDismissed: { sheet.settingsOpen = false; field.forceActiveFocus(); }
        }
    }
}
