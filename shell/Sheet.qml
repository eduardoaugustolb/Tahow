import QtQuick
import "lib/backdrop.js" as Backdrop
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
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
    readonly property bool appsMode: launcher.appsMode
    property real reveal: 0
    property bool frameReady: false
    property bool captureFailed: false
    function stateDump() { return { provider: material.compositorReady ? "compositor-live" : capture.hasContent ? "snapshot" : "simulated", width: panel.width, height: panel.height, columns: cols, gridWidth: grid.width, cellWidth: cellWidth, frameReady: frameReady, captureHasContent: capture.hasContent, captureFailed: captureFailed, bubble: panel.bubble }; }
    readonly property real targetWidth: Math.max(0, Math.min(width - Tokens.px(24), Tokens.px(660)))
    readonly property int inset: Tokens.px(22)
    readonly property int cols: Math.max(1, Math.min(launcher.columns,
        Math.floor((targetWidth - 2 * inset) / Tokens.px(110))))
    readonly property real cellWidth: Math.max(0, panel.width - 2 * inset) / cols
    readonly property int rowHeight: Tokens.px(108)
    readonly property var sections: Catalog.shelves(launcher.results, launcher.section,
        launcher.query, Catalog.strings(launcher.shared.pinnedApps), cols)
    readonly property var searchResults: {
        if (launcher.category === "files") return launcher.recentResults;
        if (launcher.category === "actions") return launcher.actionResults;
        if (launcher.category === "clipboard") return launcher.clipboardResults;
        return launcher.searchResults;
    }
    readonly property var visibleApps: appsMode ? sections.reduce((apps, group) => apps.concat(group.entries), []) : searchResults
    onVisibleAppsChanged: launcher.selected = 0

    function selectSection(section) {
        field.clear();
        launcher.query = "";
        launcher.section = section;
        launcher.selected = 0;
        grid.contentY = 0;
        field.forceActiveFocus();
    }

    function selectCategory(category, keepQuery) {
        if (!keepQuery || category === "clipboard" || launcher.category === "clipboard") launcher.query = "";
        launcher.category = category;
        launcher.section = "all";
        launcher.selected = 0;
        grid.contentY = 0;
        resultsList.positionViewAtBeginning();
        field.forceActiveFocus();
    }

    function toggleMode() { selectCategory(appsMode ? "search" : "apps", true); }

    function move(delta) {
        launcher.selected = Math.max(0, Math.min(visibleApps.length - 1, launcher.selected + delta));
    }
    function moveRow(direction) {
        const selected = launcher.selected;
        const rows = Catalog.shelfRows(sections, cols);
        const row = rows.findIndex(row => selected >= row.start && selected < row.start + row.length);
        const next = rows[row + direction];
        if (row >= 0 && next)
            launcher.selected = next.start + Math.min(selected - rows[row].start, next.length - 1);
    }

    readonly property color ink: launcher.ink
    readonly property color iconInk: Theme.alpha(ink, 1)
    readonly property color accent: Theme.materialAccent(Config.palette)
    readonly property bool captureAllowed: launcher.glass && !captureFailed && Config.palette.screenCapture && !material.compositorAvailable
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
        property real modeBubble: sheet.appsMode ? 1 : 0
        readonly property real modeBlend: Math.max(0, Math.min(1, modeBubble))
        Behavior on modeBubble {
            enabled: !sheet.launcher.reduced
            SpringAnimation { spring: sheet.launcher.spring; damping: sheet.launcher.damping; epsilon: 0.001 }
        }
        transformOrigin: Item.Top
        Behavior on bubble {
            enabled: !sheet.launcher.reduced
            SpringAnimation { spring: sheet.launcher.spring; damping: sheet.launcher.damping; epsilon: 0.001 }
        }
        property real bubbleWidth: sheet.targetWidth
        property real bubbleHeight: sheet.appsMode ? Math.min(maxHeight, Tokens.px(644)) : searchHeight
        ResizeTransition on bubbleWidth { options: Config.palette }
        ResizeTransition on bubbleHeight { options: Config.palette }
        width: Math.max(0, Math.min(sheet.width, bubbleWidth))
        readonly property real maxHeight: Math.max(0, sheet.height - Tokens.px(32))
        readonly property real searchHeight: Math.min(maxHeight,
            header.height + Math.max(1, Math.min(sheet.searchResults.length, 6)) * Tokens.px(50) + Tokens.px(10))
        height: Math.min(maxHeight, Math.max(header.height, bubbleHeight))
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Tokens.px(16), (sheet.height - height) * Math.max(0, Math.min(1, Config.palette.palettePosition))) + (1 - bubble) * Tokens.px(-18)
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
            compositorWithoutCapture: true
            texture: capture.hasContent ? frozen : null
            textureRect: sheet.width > 0 && sheet.height > 0 ? Qt.rect(panel.x / sheet.width, panel.y / sheet.height, panel.width / sheet.width, panel.height / sheet.height) : Qt.rect(0, 0, 1, 1)
            onCompositorAvailableChanged: if (compositorAvailable) {
                captureDelay.stop();
                if (!capture.hasContent) capture.captureSource = null;
                sheet.frameReady = true;
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: material.radius
            color: sheet.launcher.glass ? Theme.alpha(sheet.launcher.tint, 0.48 * (1 - material.liquidMix)) : "transparent"
            border.color: Theme.alpha(sheet.ink, 0.15 * (1 - material.liquidMix))
        }
        MouseArea { anchors.fill: parent }

        Item {
            id: header
            x: sheet.inset
            width: parent.width - 2 * x
            height: Tokens.px(102) + (clipboardStatus.visible ? clipboardStatus.height : 0)

            readonly property int searchHeight: Tokens.px(58)

            Icon {
                id: mark
                y: (header.searchHeight - height) / 2
                text: "search"
                size: Tokens.px(22)
                color: sheet.iconInk
            }
            TextField {
                id: field
                anchors { left: mark.right; leftMargin: Tokens.px(12); right: controls.left; rightMargin: Tokens.px(8) }
                y: (header.searchHeight - height) / 2
                padding: 0
                focus: true
                background: null
                text: sheet.launcher.query
                placeholderText: I18n.tr(sheet.appsMode ? "Search applications" : "Spotlight")
                Accessible.name: placeholderText
                placeholderTextColor: Theme.alpha(sheet.ink, 0.65)
                color: sheet.ink
                font.family: sheet.launcher.fontFamily
                font.pixelSize: Tokens.px(21)
                selectByMouse: true
                onTextEdited: {
                    sheet.launcher.query = text;
                    grid.contentY = 0;
                    resultsList.positionViewAtBeginning();
                }
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    if (event.modifiers & Qt.ControlModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
                        sheet.selectCategory(["apps", "files", "actions", "clipboard"][event.key - Qt.Key_1]);
                        event.accepted = true;
                        return;
                    }
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (text.length || sheet.launcher.section !== "all") sheet.selectSection("all");
                        else if (sheet.launcher.category !== "search") sheet.selectCategory("search");
                        else sheet.launcher.hide();
                        break;
                    case Qt.Key_Return: case Qt.Key_Enter:
                        sheet.launcher.launch(sheet.visibleApps[sheet.launcher.selected]);
                        break;
                    case Qt.Key_Down: sheet.appsMode ? sheet.moveRow(1) : sheet.move(1); break;
                    case Qt.Key_Up: sheet.appsMode ? sheet.moveRow(-1) : sheet.move(-1); break;
                    case Qt.Key_Left: if (text.length || !sheet.appsMode) return; sheet.move(-1); break;
                    case Qt.Key_Right: if (text.length || !sheet.appsMode) return; sheet.move(1); break;
                    case Qt.Key_Tab: case Qt.Key_Backtab:
                        if (event.modifiers & Qt.ControlModifier) { sheet.toggleMode(); break; }
                        if (!sheet.appsMode) return;
                        const ids = ["all"].concat(Catalog.groups.map(group => group.id));
                        const step = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
                        sheet.selectSection(ids[(ids.indexOf(sheet.launcher.section) + step + ids.length) % ids.length]);
                        break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }
            ToolButton {
                id: controls
                anchors { right: parent.right }
                y: (header.searchHeight - height) / 2
                width: Tokens.px(34)
                height: width
                Accessible.name: I18n.tr("Settings")
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        text: "settings"
                        size: Tokens.px(20)
                        color: sheet.iconInk
                    }
                }
                background: Rectangle {
                    radius: Tokens.px(10)
                    color: controls.hovered || controls.visualFocus ? Theme.alpha(sheet.ink, 0.12) : "transparent"
                }
                onClicked: {
                    sheet.launcher.hide();
                    Host.openSettingsRequested();
                }
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: header.searchHeight }
                spacing: Tokens.px(4)
                Repeater {
                    model: [
                        { id: "search", label: "Search" },
                        { id: "apps", label: "Applications" },
                        { id: "files", label: "Recent files" },
                        { id: "actions", label: "Actions" },
                        { id: "clipboard", label: "Clipboard" }
                    ]
                    ToolButton {
                        id: categoryButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        implicitHeight: Tokens.px(34)
                        text: I18n.tr(modelData.label)
                        checkable: true
                        autoExclusive: true
                        checked: sheet.launcher.category === modelData.id
                        contentItem: Text {
                            text: categoryButton.text
                            color: sheet.ink
                            font.family: sheet.launcher.fontFamily
                            font.pixelSize: Tokens.px(12)
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            radius: Tokens.px(9)
                            color: Theme.alpha(sheet.ink, categoryButton.checked ? 0.18 :
                                categoryButton.hovered || categoryButton.visualFocus ? 0.10 : 0)
                        }
                        onClicked: sheet.selectCategory(modelData.id)
                    }
                }
            }
            Text {
                id: clipboardStatus
                y: Tokens.px(102)
                width: parent.width
                readonly property string status: sheet.launcher.historyProvider?.status || ""
                visible: sheet.launcher.wantsClipboardHistory &&
                    (status === "Copied to clipboard" || status === "Could not restore the clipboard item.")
                text: I18n.tr(status)
                color: Theme.alpha(sheet.ink, 0.68)
                font.family: sheet.launcher.fontFamily
                font.pixelSize: Tokens.px(12)
                Accessible.role: Accessible.StatusBar
            }
        }

        ListView {
            id: resultsList
            visible: !sheet.appsMode || opacity > 0
            enabled: !sheet.appsMode
            opacity: Math.max(0, 1 - 2 * panel.modeBlend)
            anchors { top: header.bottom; bottom: parent.bottom; left: header.left; right: header.right; bottomMargin: Tokens.px(10) }
            clip: true
            model: visible ? sheet.searchResults : []
            currentIndex: launcher.selected
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: ItemDelegate {
                id: hit
                required property var modelData
                required property int index
                width: resultsList.width
                height: Tokens.px(50)
                highlighted: sheet.launcher.selected === index
                text: modelData.name
                onClicked: sheet.launcher.launch(modelData)
                background: Rectangle {
                    radius: Tokens.px(12)
                    color: Theme.alpha(sheet.accent, hit.highlighted ? 0.22 : hit.hovered ? 0.10 : 0)
                }
                contentItem: Item {
                    AppIcon {
                        id: appMark
                        anchors.verticalCenter: parent.verticalCenter
                        size: Tokens.px(32)
                        styleEnabled: true
                        styleInk: sheet.iconInk
                        fallback: hit.modelData.glyph || "apps"
                        fallbackColor: sheet.accent
                        source: hit.modelData.fileUrl || hit.modelData.clipboardId || hit.modelData.actionId
                            || hit.modelData.webUrl || hit.modelData.calculation !== undefined
                            ? "" : Quickshell.iconPath(hit.modelData.icon || "application-x-executable", true)
                    }
                    Column {
                        anchors { left: appMark.right; leftMargin: Tokens.px(10); right: parent.right; verticalCenter: parent.verticalCenter }
                        Text {
                            width: parent.width
                            text: hit.text
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: sheet.ink
                            font.family: sheet.launcher.fontFamily
                            font.pixelSize: Tokens.px(14)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: hit.modelData.genericName || hit.modelData.comment || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.alpha(sheet.ink, 0.68)
                            font.family: sheet.launcher.fontFamily
                            font.pixelSize: Tokens.px(11)
                        }
                    }
                }
            }
        }
        Flickable {
            id: grid
            visible: sheet.appsMode || opacity > 0
            enabled: sheet.appsMode
            opacity: Math.max(0, 2 * panel.modeBlend - 1)
            anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: sheet.inset; topMargin: 0 }
            clip: true
            contentWidth: width
            contentHeight: shelves.height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: shelves
                width: grid.width
                spacing: Tokens.px(12)
                Repeater {
                    model: grid.visible ? sheet.sections : []
                    delegate: Column {
                        id: shelf
                        required property var modelData
                        width: shelves.width

                        Rectangle { width: parent.width; height: 1; color: Theme.alpha(sheet.ink, 0.16) }
                        Item {
                            width: parent.width
                            height: Tokens.px(42)
                            Text {
                                anchors { left: parent.left; right: action.left; verticalCenter: parent.verticalCenter }
                                text: I18n.tr(shelf.modelData.label)
                                color: sheet.ink
                                elide: Text.ElideRight
                                font.family: sheet.launcher.fontFamily
                                font.pixelSize: Tokens.px(15)
                                font.weight: Font.DemiBold
                            }
                            ToolButton {
                                id: action
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                visible: shelf.modelData.more || (sheet.launcher.section !== "all" || sheet.launcher.query.length > 0)
                                text: I18n.tr(shelf.modelData.more ? (shelf.modelData.id === "suggestions" ? "Show more" : "Show all") : "All applications")
                                contentItem: Text {
                                    text: action.text
                                    color: sheet.ink
                                    font.family: sheet.launcher.fontFamily
                                    font.pixelSize: Tokens.px(12)
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: null
                                onClicked: sheet.selectSection(shelf.modelData.more ? shelf.modelData.id : "all")
                            }
                        }
                        Grid {
                            columns: sheet.cols
                            Repeater {
                                model: shelf.modelData.entries
                                delegate: Item {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    property int appIndex: shelf.modelData.start + index
                                    readonly property bool selected: appIndex === sheet.launcher.selected
                                    width: sheet.cellWidth
                                    height: sheet.rowHeight
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.name
                                    Accessible.onPressAction: sheet.launcher.launch(modelData)
                                    onSelectedChanged: if (selected) {
                                        const top = mapToItem(shelves, 0, 0).y;
                                        if (top < grid.contentY) grid.contentY = top;
                                        else if (top + height > grid.contentY + grid.height)
                                            grid.contentY = Math.max(0, top + height - grid.height);
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: Tokens.px(4)
                                        radius: Tokens.px(14)
                                        color: Theme.alpha(sheet.accent, 0.20)
                                        border.color: Theme.alpha(sheet.accent, 0.45)
                                        visible: tile.selected || tileMouse.containsMouse
                                    }
                                    AppIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Tokens.px(5)
                                        size: Math.min(Tokens.px(58), tile.width - Tokens.px(8))
                                        styleEnabled: true
                                        styleInk: sheet.iconInk
                                        fallback: tile.modelData.glyph || "apps"
                                        fallbackColor: sheet.accent
                                        source: Quickshell.iconPath(tile.modelData.icon || "application-x-executable", true)
                                    }
                                    Text {
                                        anchors { bottom: parent.bottom; bottomMargin: Tokens.px(15); left: parent.left; right: parent.right; margins: Tokens.px(6) }
                                        text: tile.modelData.name
                                        color: sheet.ink
                                        font.family: sheet.launcher.fontFamily
                                        font.pixelSize: Tokens.px(13)
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sheet.launcher.launch(tile.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: header.width
            y: header.height + (parent.height - header.height - height) / 2
            visible: !sheet.visibleApps.length
            text: {
                if (sheet.launcher.category === "files") return I18n.tr("No recent files found");
                if (sheet.launcher.category === "actions") return I18n.tr("No actions found");
                if (sheet.launcher.category === "clipboard") {
                    const provider = sheet.launcher.historyProvider;
                    if (!provider) return I18n.tr("Clipboard history is unavailable.");
                    if (!provider.historyAllowed) return I18n.tr("Choose Show history in the input panel to browse clipboard history.");
                    return I18n.tr(provider.status === "Clipboard history is unavailable." ? provider.status : "No clipboard history");
                }
                return I18n.tr("No applications found");
            }
            color: sheet.ink
            font.family: sheet.launcher.fontFamily
            font.pixelSize: Tokens.px(13)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
