pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "lib/input-panel.js" as Input
import "lib/backdrop.js" as Backdrop
import "lib/keymoji/Search.mjs" as EmojiSearch
import "lib/keymoji/Navigation.mjs" as EmojiNavigation
import "lib/keymoji/Input.mjs" as EmojiInput

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:tahow-input"
    WlrLayershell.keyboardFocus: searching ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int page: 0
    property bool searching: false
    property var emojiTarget: null
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    property string pendingEmoji: ""
    property var recentEmoji: []
    property var emojiCatalog: null
    property var emojiPortuguese: null
    property var emojiEnglish: null
    property bool loadEmojiCatalog: false
    property bool emojiLoadFailed: false
    readonly property var emojiRows: emojiCatalog && emojiPortuguese && emojiEnglish
        ? EmojiSearch.indexCatalog(emojiCatalog, I18n.lang === "pt-BR" ? emojiPortuguese : emojiEnglish,
            emojiEnglish, {}, I18n.lang === "pt-BR" ? "pt" : "en")
        : []
    property bool capturingGlass: false
    readonly property var options: Config.input
    property real reveal: 0
    property real bubble: 0
    readonly property bool reducedMotion: options.motion === "reduced"
    SpringAnimation {
        id: bubbleOpening
        target: root
        property: "bubble"
        to: 1
        spring: Theme.springFor(root.options.motion)
        damping: Theme.dampingFor(root.options.motion)
        epsilon: 0.001
    }
    NumberAnimation {
        id: opening
        target: root
        property: "reveal"
        to: 1
        duration: root.options.fastDuration
        easing.type: root.options.easing
    }
    readonly property bool dark: options.style === "black" || options.appearance === "dark"
        || (options.appearance !== "light" && Theme.autoDark)
    readonly property color ink: dark ? "#ffffff" : "#000000"
    readonly property color secondary: Theme.alpha(ink, 0.65)
    readonly property color accent: Theme.materialAccent(options)
    readonly property color separator: Theme.alpha(ink, 0.12)
    readonly property bool captureAllowed: options.style !== "black" && options.screenCapture
        && Host.desktopCaptureAllowed && Host.desktopCaptureReady
    readonly property string emojiFont: Qt.fontFamilies().includes("Apple Color Emoji") ? "Apple Color Emoji" : "emoji"
    property bool uppercase: false
    property bool symbols: false
    property bool historyAllowed: false
    property bool externalHistoryVisible: false
    readonly property bool historyVisible: historyAllowed && ((visible && page === 1) || externalHistoryVisible)
    readonly property string clipboardScript: decodeURIComponent(Qt.resolvedUrl("bin/restore-clipboard.ts").toString().replace(/^file:\/\//, ""))
    property var entries: []
    property string status: ""
    readonly property var pages: ["Virtual keyboard", "Clipboard", "Emojis"]

    function toggle(targetPage) {
        if (visible && page === targetPage) { visible = false; return; }
        if (!visible) {
            screen = Quickshell.screens.find(output => output.name === Host.focusedOutput) ?? null;
            if (captureAllowed && screen && !material.compositorAvailable) {
                capturingGlass = true;
                Host.beginCapture();
                captureTimeout.start();
                capture.captureSource = screen;
            }
            visible = true;
            if (!capturingGlass) revealPanel();
        }
        page = targetPage;
    }
    function revealPanel() {
        if (reducedMotion) {
            reveal = 1;
        } else {
            opening.start();
            bubbleOpening.start();
        }
    }
    function run(command, fromSpotlight) {
        if ((!visible && !fromSpotlight) || action.running) return;
        status = "";
        action.command = ["env", "PATH=" + LoginWallpaper.runtimePath, ...command];
        action.running = true;
    }
    function typeText(text) { run(["wtype", "--", text]); }
    function pickEmoji(emoji) {
        if (action.running || emojiRelease.running) return;
        pendingEmoji = emoji;
        if (!searching) {
            typeText(emoji);
            return;
        }
        releaseSearch();
        emojiRelease.restart();
    }
    function releaseSearch() {
        if (!searching) return;
        searching = false;
        focusRestore.target = emojiTarget;
        focusRestore.restart();
    }
    Timer {
        id: focusRestore
        property var target: null
        interval: 35
        onTriggered: {
            if (target && !root.searching && !root.activeToplevel) target.activate();
            target = null;
        }
    }
    Timer {
        id: emojiRelease
        interval: 100
        onTriggered: {
            if (!root.visible || root.page !== 2) return;
            try {
                root.run(EmojiInput.command(root.pendingEmoji, root.emojiTarget, root.activeToplevel, root.searching));
            } catch (_) {
                root.status = "Focus the application where you want to insert the emoji.";
                root.pendingEmoji = "";
            }
        }
    }
    function restoreHistory(entry, fromSpotlight) {
        if (!historyVisible || (fromSpotlight && !externalHistoryVisible)) return;
        run(["bun", clipboardScript, entry], fromSpotlight);
    }
    function refreshHistory() {
        if (!historyVisible || history.running) return;
        entries = [];
        status = "";
        history.running = true;
    }
    onHistoryVisibleChanged: {
        if (historyVisible) refreshHistory();
        else {
            entries = [];
            status = "";
            history.running = false;
        }
    }
    onPageChanged: {
        releaseSearch();
        pendingEmoji = "";
        emojiTarget = null;
        emojiRelease.stop();
        if (!historyVisible) entries = [];
        status = "";
        if (page === 2) {
            status = emojiLoadFailed ? "Could not load emojis." : "";
            loadEmojiCatalog = true;
        }
        refreshHistory();
    }
    onEmojiLoadFailedChanged: if (emojiLoadFailed && visible && page === 2)
        status = "Could not load emojis."

    FileView {
        path: root.loadEmojiCatalog ? Qt.resolvedUrl("lib/keymoji/data/emojis.json") : ""
        onLoaded: root.emojiCatalog = JSON.parse(this.text())
        onLoadFailed: root.emojiLoadFailed = true
    }
    FileView {
        path: root.loadEmojiCatalog ? Qt.resolvedUrl("lib/keymoji/data/pt.json") : ""
        onLoaded: root.emojiPortuguese = JSON.parse(this.text())
        onLoadFailed: root.emojiLoadFailed = true
    }
    FileView {
        path: root.loadEmojiCatalog ? Qt.resolvedUrl("lib/keymoji/data/en.json") : ""
        onLoaded: root.emojiEnglish = JSON.parse(this.text())
        onLoadFailed: root.emojiLoadFailed = true
    }
    onVisibleChanged: if (!visible) {
        opening.stop();
        bubbleOpening.stop();
        reveal = 0;
        bubble = 0;
        page = 0;
        if (!historyVisible) entries = [];
        status = "";
        uppercase = false;
        symbols = false;
        if (!historyVisible) history.running = false;
        capture.captureSource = null;
        finishCapture();
    }

    Process {
        id: action
        onExited: code => {
            if (command[2] === "bun") {
                if (root.historyVisible)
                    root.status = code === 0 ? "Copied to clipboard" : "Could not restore the clipboard item.";
                return;
            }
            if (!root.visible) return;
            if (code !== 0)
                root.status = "Could not type. Check wtype and compositor support.";
            else if (root.pendingEmoji)
                root.recentEmoji = [root.pendingEmoji].concat(root.recentEmoji.filter(emoji => emoji !== root.pendingEmoji)).slice(0, 48);
            root.pendingEmoji = "";
        }
    }
    Process {
        running: root.historyAllowed
        command: ["env", "PATH=" + LoginWallpaper.runtimePath, "wl-paste", "--type", "image", "--watch",
            "sh", "-c", 'if [ "$CLIPBOARD_STATE" = data ] && cliphist store; then echo stored; fi']
        stdout: SplitParser { onRead: historyRefresh.restart() }
    }
    Timer {
        id: historyRefresh
        interval: 120
        onTriggered: {
            if (!root.historyVisible) return;
            if (history.running) restart();
            else root.refreshHistory();
        }
    }
    Process {
        id: history
        command: ["env", "PATH=" + LoginWallpaper.runtimePath, "cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: if (root.historyVisible)
                root.entries = Input.clipboardEntries(this.text)
        }
        onExited: code => {
            if (code !== 0 && root.historyVisible)
                root.status = "Clipboard history is unavailable.";
        }
    }

    function finishCapture() {
        captureTimeout.stop();
        if (capturingGlass) {
            capturingGlass = false;
            Host.endCapture();
            if (visible) revealPanel();
        }
    }
    Component.onDestruction: if (capturingGlass) Host.endCapture()

    Timer {
        id: captureTimeout
        // Keep the frame clean without blocking the opening on a slow capture.
        interval: 50
        onTriggered: {
            capture.captureSource = null;
            root.finishCapture();
        }
    }
    ScreencopyView {
        id: capture
        width: root.screen?.width ?? 0
        height: root.screen?.height ?? 0
        captureSource: null
        live: false
        paintCursor: false
        onHasContentChanged: if (hasContent) root.finishCapture()
    }
    ShaderEffectSource {
        id: frozen
        width: capture.width
        height: capture.height
        sourceItem: capture
        textureSize: {
            const size = Backdrop.size(width, height);
            return Qt.size(size.width, size.height);
        }
        mipmap: true
        hideSource: true
        visible: false
    }
    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            if (!panel.contains(panel.mapFromItem(parent, mouse.x, mouse.y))) root.visible = false;
        }
    }

    Item {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        opacity: root.reveal
        transformOrigin: Item.Bottom
        scale: root.reducedMotion ? 1 : 0.88 + root.bubble * 0.12
        enabled: !root.capturingGlass
        transform: Translate {
            id: openingOffset
            y: root.reducedMotion ? 0 : (1 - root.bubble) * 18
        }
        width: Math.min(740, Math.max(280, (root.screen?.width ?? 740) - 24))
        height: Math.min(365, Math.max(240, (root.screen?.height ?? 365) - 36))
        ResizeTransition on width { options: root.options }
        ResizeTransition on height { options: root.options }

        Glass {
            id: material
            objectName: "tahow-input-material"
            anchors.fill: parent
            radius: 30
            options: root.options
            tint: options.style === "black" ? "#000000" : Theme.materialTint(options, root.dark)
            compositorTarget: "quickshell:tahow-input"
            compositorWithoutCapture: true
            texture: capture.hasContent ? frozen : null
            textureRect: capture.width > 0 && capture.height > 0
                ? Qt.rect((panel.x + width * (1 - panel.scale) / 2) / capture.width,
                    (panel.y + height * (1 - panel.scale) + openingOffset.y) / capture.height,
                    width * panel.scale / capture.width, height * panel.scale / capture.height)
                : Qt.rect(0, 0, 1, 1)
            onCompositorAvailableChanged: if (compositorAvailable && root.capturingGlass) {
                capture.captureSource = null;
                root.finishCapture();
            }
            shadow: false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 9

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Txt { Layout.fillWidth: true; sourceText: root.pages[root.page]; size: 23; color: root.ink }
                Key {
                    text: "×"
                    font.pixelSize: 22
                    implicitWidth: 34
                    implicitHeight: 34
                    accessibleLabel: I18n.tr("Close window")
                    onClicked: root.visible = false
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.separator }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: root.pages
                    Key {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        text: I18n.tr(modelData)
                        selected: root.page === index
                        onClicked: root.page = index
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.page

                ColumnLayout {
                    spacing: 4
                    Repeater {
                        model: Input.keyboardRows(root.symbols, root.uppercase)
                        RowLayout {
                            id: keyRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 0
                            spacing: 4
                            Repeater {
                                model: keyRow.modelData
                                Key {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 0
                                    text: modelData
                                    enabled: !action.running
                                    onClicked: {
                                        root.typeText(modelData);
                                        root.uppercase = false;
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Key {
                            text: "⇧"; accessibleLabel: I18n.tr("Shift key")
                            selected: root.uppercase
                            enabled: !root.symbols
                            onClicked: root.uppercase = !root.uppercase
                        }
                        Key {
                            text: root.symbols ? "ABC" : "#+="
                            accessibleLabel: I18n.tr(root.symbols ? "Letters" : "Symbols")
                            onClicked: { root.symbols = !root.symbols; root.uppercase = false; }
                        }
                        Key {
                            Layout.fillWidth: true
                            text: I18n.tr("Space key")
                            enabled: !action.running
                            onClicked: root.typeText(" ")
                        }
                        Key {
                            text: "⌫"; accessibleLabel: I18n.tr("Backspace key")
                            enabled: !action.running
                            onClicked: root.run(["wtype", "-k", "BackSpace"])
                        }
                        Key {
                            text: "↵"; accessibleLabel: I18n.tr("Enter key")
                            enabled: !action.running
                            onClicked: root.run(["wtype", "-k", "Return"])
                        }
                        Repeater {
                            model: Input.arrowKeys
                            Key {
                                required property var modelData
                                text: modelData.glyph
                                accessibleLabel: I18n.tr(modelData.label)
                                implicitWidth: 24
                                enabled: !action.running
                                onClicked: root.run(["wtype", "-k", modelData.key])
                            }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Key {
                            text: I18n.tr("Paste current clipboard")
                            enabled: !action.running
                            onClicked: root.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"])
                        }
                        Item { Layout.fillWidth: true }
                        Key {
                            visible: root.historyAllowed
                            text: I18n.tr("Refresh history")
                            enabled: !history.running
                            onClicked: root.refreshHistory()
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ColumnLayout {
                            visible: !root.historyAllowed
                            width: parent.width
                            anchors.centerIn: parent
                            spacing: 12
                            Txt {
                                Layout.fillWidth: true
                                sourceText: "Clipboard history may contain personal information. Show saved items and record copied images until Tahow closes?"
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                color: root.secondary
                            }
                            Key {
                                Layout.alignment: Qt.AlignHCenter
                                text: I18n.tr("Show history")
                                selected: true
                                onClicked: { root.historyAllowed = true; root.refreshHistory(); }
                            }
                        }
                        Txt {
                            anchors.centerIn: parent
                            visible: root.historyAllowed && !history.running && root.entries.length === 0 && root.status === ""
                            sourceText: "No clipboard history"
                            color: root.secondary
                        }
                        ListView {
                            id: clipboardList
                            anchors.fill: parent
                            visible: root.historyAllowed
                            clip: true
                            spacing: 4
                            model: root.entries
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Key {
                                id: historyEntry
                                required property var modelData
                                width: clipboardList.width - 10
                                implicitHeight: modelData.imageFormat ? 64 : 30
                                leftAligned: true
                                text: modelData.preview
                                thumbnail: previewImage.text
                                Process {
                                    running: !!historyEntry.modelData.imageFormat
                                    command: ["env", "PATH=" + LoginWallpaper.runtimePath, "bun", root.clipboardScript,
                                        historyEntry.modelData.id, historyEntry.modelData.imageFormat]
                                    stdout: StdioCollector { id: previewImage }
                                }
                                enabled: !action.running
                                onClicked: root.restoreHistory(modelData.id)
                            }
                        }
                    }
                }

                Loader {
                    active: root.visible && root.page === 2
                    sourceComponent: emojiPage
                }
            }
            Txt {
                Layout.fillWidth: true
                visible: root.status !== ""
                sourceText: root.status
                color: root.secondary
                Accessible.role: Accessible.StaticText
            }
        }

        Component {
            id: emojiPage
            ColumnLayout {
                id: picker
                property string group: "all"
                property string query: ""
                readonly property var groups: ["All", "Recent", "Faces", "People and body", "Animals and nature",
                    "Food and drink", "Travel and places", "Activities", "Objects", "Symbols", "Flags"]
                readonly property var results: EmojiSearch.search(root.emojiRows, query, group, [], root.recentEmoji)
                onResultsChanged: {
                    if (!emojiGrid) return;
                    emojiGrid.currentIndex = results.length ? 0 : -1;
                    emojiGrid.positionViewAtBeginning();
                }

                Timer {
                    id: emojiDebounce
                    interval: 110
                    onTriggered: picker.query = searchField.text
                }
                function flushSearch() {
                    emojiDebounce.stop();
                    query = searchField.text;
                }
                function navigate(direction) {
                    flushSearch();
                    emojiGrid.currentIndex = EmojiNavigation.nextIndex(emojiGrid.currentIndex, direction,
                        results.length, Math.floor(emojiGrid.width / emojiGrid.cellWidth),
                        Math.floor(emojiGrid.height / emojiGrid.cellHeight));
                    emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                }

                RowLayout {
                    Layout.fillWidth: true
                    Key {
                        visible: !root.searching
                        text: searchField.text || I18n.tr("Search emojis")
                        accessibleLabel: I18n.tr("Search emojis")
                        leftAligned: true
                        Layout.fillWidth: true
                        enabled: !emojiRelease.running && !action.running
                        onClicked: {
                            root.emojiTarget = root.activeToplevel;
                            root.searching = true;
                            searchField.forceActiveFocus();
                        }
                    }
                    TextField {
                        id: searchField
                        objectName: "tahow-emoji-search"
                        visible: root.searching
                        Layout.fillWidth: true
                        placeholderText: I18n.tr("Search emojis")
                        selectionColor: root.accent
                        color: root.ink
                        placeholderTextColor: root.secondary
                        font.family: Theme.font
                        background: Rectangle { radius: 8; color: Theme.alpha(root.ink, 0.08); border.color: root.accent }
                        onTextChanged: emojiDebounce.restart()
                        onAccepted: {
                            picker.flushSearch();
                            const item = picker.results[emojiGrid.currentIndex];
                            if (item) root.pickEmoji(item.e);
                        }
                        Keys.onLeftPressed: event => { if (event.modifiers & Qt.AltModifier) picker.navigate("left"); else event.accepted = false; }
                        Keys.onRightPressed: event => { if (event.modifiers & Qt.AltModifier) picker.navigate("right"); else event.accepted = false; }
                        Keys.onUpPressed: picker.navigate("up")
                        Keys.onDownPressed: picker.navigate("down")
                        Keys.onEscapePressed: root.releaseSearch()
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    contentWidth: categoryRow.width
                    contentHeight: categoryRow.height
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    Accessible.name: I18n.tr("Emoji category")
                    ScrollBar.horizontal: ScrollBar {}
                    Row {
                        id: categoryRow
                        spacing: 4
                        Repeater {
                            model: picker.groups
                            Key {
                                required property int index
                                required property string modelData
                                readonly property string category: EmojiSearch.groupIds.filter(id => id !== "favorites")[index]
                                text: I18n.tr(modelData)
                                selected: picker.group === category
                                onClicked: picker.group = category
                            }
                        }
                    }
                }
                GridView {
                    id: emojiGrid
                    objectName: "tahow-emoji-grid"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: width / Math.max(1, Math.floor(width / 48))
                    cellHeight: 48
                    model: picker.results
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Key {
                        required property var modelData
                        required property int index
                        width: emojiGrid.cellWidth - 4
                        height: emojiGrid.cellHeight - 4
                        font.family: root.emojiFont
                        font.pixelSize: 25
                        text: modelData.e
                        accessibleLabel: modelData.n
                        selected: root.searching && emojiGrid.currentIndex === index
                        enabled: !action.running && !emojiRelease.running
                        onClicked: root.pickEmoji(modelData.e)
                    }
                    Txt {
                        anchors.centerIn: parent
                        visible: root.emojiRows.length > 0 && picker.results.length === 0
                        sourceText: "No emojis found"
                        color: root.secondary
                    }
                }
            }
        }
    }

    component Key: Button {
        id: key
        property bool selected: false
        property bool leftAligned: false
        property string accessibleLabel: text
        property string iconName: ""
        property url thumbnail: ""
        focusPolicy: Qt.NoFocus
        Accessible.name: accessibleLabel
        hoverEnabled: true
        implicitHeight: 30
        implicitWidth: Math.max(40, caption.implicitWidth + 16)
        padding: 5
        font.family: Theme.font
        font.pixelSize: 13
        ToolTip.visible: hovered && (accessibleLabel !== text || caption.truncated)
        ToolTip.text: accessibleLabel
        ToolTip.delay: 450
        contentItem: Item {
            implicitWidth: caption.implicitWidth
            Image {
                id: thumbnailImage
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: status === Image.Ready ? 76 : 0
                height: parent.height
                source: key.thumbnail
                fillMode: Image.PreserveAspectFit
                cache: false
            }
            Text {
                id: caption
                anchors.fill: parent
                anchors.leftMargin: thumbnailImage.width ? thumbnailImage.width + 8 : 0
                visible: key.iconName === ""
                text: key.text
                font: key.font
                color: key.enabled ? root.ink : Theme.alpha(root.ink, 0.32)
                elide: Text.ElideRight
                textFormat: Text.PlainText
                horizontalAlignment: key.leftAligned ? Text.AlignLeft : Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Icon {
                anchors.centerIn: parent
                visible: key.iconName !== ""
                text: key.iconName
                size: 16
                color: root.secondary
            }
        }
        background: Rectangle {
            radius: 8
            color: key.selected ? Theme.alpha(root.accent, key.down ? 0.36 : 0.24)
                : Theme.alpha(root.ink, key.down ? 0.19 : key.hovered ? 0.13 : 0.07)
            border.color: key.selected ? Theme.alpha(root.accent, 0.7) : root.separator
        }
    }
}
