import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    function stateDump() { return { width: panel.width, height: panel.height, columns: cols, gridWidth: grid.width, cellWidth: grid.cellWidth, frameReady: frameReady, captureHasContent: capture.hasContent, captureFailed: captureFailed, bubble: panel.bubble }; }
    readonly property real targetWidth: Math.min(width - 32, 550)
    readonly property int cols: Math.max(1, Math.min(launcher.columns,
        Math.floor((targetWidth - 28) / 70)))
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
        textureSize: Qt.size(Math.max(1, sheet.width), Math.max(1, sheet.height))
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
        height: Math.min(width * 380 / 550, sheet.height - 80)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Tokens.px(56), (sheet.height - height) * Math.max(0, Math.min(1, Config.palette.palettePosition))) + (1 - bubble) * Tokens.px(-18)
        opacity: sheet.reveal
        scale: sheet.launcher.reduced ? 1 : 0.88 + bubble * 0.12

        RectangularShadow {
            anchors.fill: parent
            radius: Tokens.px(22)
            blur: Tokens.px(36); spread: Tokens.px(-8)
            offset.y: Tokens.px(12)
            color: Qt.rgba(0, 0, 0, 0.30)
            visible: !sheet.launcher.glass
        }
        Rectangle {
            anchors.fill: parent
            radius: Tokens.px(22)
            color: sheet.launcher.tint
            visible: !glass.visible
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, sheet.launcher.dark ? 0.12 : 0.5)
        }
        NativeGlass {
            id: glass
            anchors.fill: parent
            visible: sheet.launcher.glass && sheet.frameReady
            src: frozen
            sourceRect: Qt.rect(panel.x / sheet.width, panel.y / sheet.height, panel.width / sheet.width, panel.height / sheet.height)
            topLeftRadius: Tokens.px(22); topRightRadius: Tokens.px(22)
            bottomLeftRadius: Tokens.px(22); bottomRightRadius: Tokens.px(22)
            tintColor: sheet.launcher.tint
            tintAmount: sheet.launcher.glassOpacity
            frost: Math.max(1.5, sheet.launcher.frost / 5)
            // General optics apply unless the palette has component overrides.
            bezel: Config.palette.bezel
            thickness: Config.palette.thickness
            ior: Config.palette.ior
            dispersion: Config.palette.dispersion
            nest: 1
            rim: sheet.launcher.preferences.rim === false ? 0 : 0.16
        }
        // Same material veil and intensity as the island's Glass primitive.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Tokens.px(21)
            visible: glass.visible
            color: sheet.launcher.tint
            opacity: sheet.launcher.glassOpacity
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 0.5
            radius: 22
            visible: glass.visible
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, sheet.launcher.dark ? 0.08 : 0.18)
        }
        MouseArea { anchors.fill: parent }

        Item {
            id: header
            x: Tokens.px(16); y: Tokens.px(8)
            width: parent.width - x * 2; height: Tokens.px(34)
            Text {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("⌘")
                color: sheet.launcher.ink
                font.family: sheet.launcher.fontFamily
                font.pixelSize: Tokens.px(20)
            }
            TextInput {
                id: field
                anchors { left: mark.right; leftMargin: Tokens.px(10); right: settingsButton.left; rightMargin: Tokens.px(8); verticalCenter: parent.verticalCenter }
                focus: true; clip: true
                color: sheet.launcher.ink
                font.family: sheet.launcher.fontFamily
                font.pixelSize: Tokens.px(18)
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
                    text: I18n.tr("Applications")
                    color: sheet.launcher.ink; opacity: 0.65
                    font: field.font
                }
            }
            Text {
                id: settingsButton
                width: Tokens.px(30); height: parent.height
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
        Rectangle {
            x: Tokens.px(14); y: header.y + header.height + Tokens.px(3)
            width: parent.width - x * 2; height: 1
            color: sheet.launcher.ink; opacity: 0.09
        }
        Row {
            id: tabs
            x: Tokens.px(14); y: Tokens.px(52)
            width: parent.width - x * 2; height: Tokens.px(22)
            spacing: Tokens.px(5)
            Repeater {
                model: Catalog.groups
                Rectangle {
                    id: tab
                    required property var modelData
                    width: (tabs.width - tabs.spacing * 4) / 5
                    height: tabs.height; radius: Tokens.px(7)
                    color: Qt.rgba(1, 1, 1, sheet.launcher.section === modelData.id ? 0.30 : 0.10)
                    Text {
                        anchors.fill: parent; anchors.margins: Tokens.px(2)
                        text: I18n.tr(tab.modelData.label)
                        color: sheet.launcher.ink
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(10)
                        minimumPixelSize: Tokens.px(7); fontSizeMode: Text.Fit
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
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
            x: Tokens.px(16); y: Tokens.px(87)
            text: I18n.tr(sheet.launcher.query ? I18n.tr("Search results") : (sheet.launcher.section === "all" ? I18n.tr("All applications") : I18n.tr(Catalog.groups.find(g => g.id === sheet.launcher.section).label)))
            color: sheet.launcher.ink
            font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(10); font.weight: Font.DemiBold
        }
        GridView {
            id: grid
            anchors { top: sectionTitle.bottom; topMargin: Tokens.px(6); bottom: footer.top; bottomMargin: Tokens.px(4); left: parent.left; right: parent.right; leftMargin: Tokens.px(14); rightMargin: Tokens.px(14) }
            clip: true
            cellWidth: Math.floor(width / sheet.cols); cellHeight: 76
            model: ScriptModel { values: sheet.launcher.results }
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: sheet.launcher.selected
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: Tokens.px(2)
                    radius: Tokens.px(12)
                    color: sheet.launcher.ink
                    opacity: tile.index === sheet.launcher.selected ? 0.12 : (tileMouse.containsMouse ? 0.06 : 0)
                    Behavior on opacity { NumberAnimation { duration: Tokens.dur(100) } }
                }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 5
                    implicitSize: 43
                    source: Quickshell.iconPath(tile.modelData.icon || "application-x-executable", true)
                    asynchronous: true
                }
                Text {
                    x: 3; y: 54; width: parent.width - x * 2
                    text: I18n.tr(tile.modelData.name)
                    color: sheet.launcher.ink
                    font.family: sheet.launcher.fontFamily; font.pixelSize: 10
                    elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPositionChanged: sheet.launcher.selected = tile.index
                    onClicked: sheet.launcher.launch(tile.modelData)
                }
            }
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
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
            anchors { bottom: parent.bottom; bottomMargin: Tokens.px(10); left: parent.left; leftMargin: Tokens.px(18) }
            text: I18n.tr("↑↓←→ Navigate   ↵ Open   ⇥ Category   Esc Close")
            color: sheet.launcher.ink; opacity: 0.45
            font.family: sheet.launcher.fontFamily; font.pixelSize: Tokens.px(9)
        }
        PalettePreferences {
            anchors.fill: parent; anchors.margins: Tokens.px(8)
            visible: sheet.settingsOpen
            launcher: sheet.launcher
            onDismissed: { sheet.settingsOpen = false; field.forceActiveFocus(); }
        }
    }
}
