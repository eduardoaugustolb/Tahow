import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// One transparent full-screen overlay per screen holding the island, its bubbles,
// banners and the Notification Center. Only those items take input (mask).
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool focusedHere: !Host.focusedOutput || Host.focusedOutput === screenName

    // Hide everything while this monitor's workspace has a fullscreen window
    // (videos, games). Opening the island (Super+I) or the Notification Center
    // still works and brings it back until it is closed again.
    readonly property bool fullscreenHere: Host.fullscreen(screenName)
    readonly property bool hiddenForFullscreen: fullscreenHere && !island.isExpanded && !island.isLauncher && !centerShown
    visible: Config.island.islandEnabled && !hiddenForFullscreen

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    // the island itself always floats; space is reserved by `reserver` below
    exclusionMode: (Config.island.overlayBar || Config.island.reserveSpace) ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"

    readonly property bool centerShown: Notifs.centerOpen && Notifs.centerScreen === screenName
    readonly property bool explicitOpen: island.isExpanded || centerShown
    readonly property bool dismissableOpen: island.isExpanded || island.peek || centerShown
    function layoutDump() {
        return Object.assign(island.layoutDump(), {
            screen: screenName,
            islandOpacity: island.opacity,
            surfaceOpacity: win.contentItem.opacity,
            acquiringBackdrop: acquiringBackdrop,
            captureHasContent: backgroundCapture.hasContent,
            backdropReady: !!Host.backdrops[screenName]
        });
    }
    Component.onCompleted: Host.registerWindow(win)
    // Capture visibility is local to the requesting component. Never fade the
    // whole overlay: banners and Notification Center share this window too.
    readonly property bool interactive: island.isExpanded || island.isLauncher || centerShown || Notifs.replying || banners.hovered

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:island"
    WlrLayershell.keyboardFocus: interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: island
        Region { item: island.bubble }
        Region { item: island.clockBubble }
        Region { item: banners.visible ? banners : null }
        Region { item: scrim.visible ? scrim : null }
        Region { item: outsideDismiss.visible ? outsideDismiss : null }
    }

    // ── Reserve a strip at the top (like a bar) so windows tile below the island ──
    // Invisible, takes no input. Zone = island bottom + 6px − (frame edge + gaps_out),
    // because Hyprland already adds gaps_out on top of the reserved area.
    readonly property int gapsTop: Config.island.outerGaps
    PanelWindow {
        id: reserver
        screen: win.screen
        visible: Config.island.reserveSpace
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Math.max(0, Config.island.topMargin + 38 + 6 - win.gapsTop)
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:island-reserve"
    }


    property bool acquiringBackdrop: false
    property bool captureHidesIsland: false
    property string pendingKind: ""
    property int pendingValue: 0
    function prepare(kind,value) {
        pendingKind = kind; pendingValue = value;
        if (acquiringBackdrop) return;
        if ((island.peek || island.isExpanded || centerShown) && Host.backdrops[screenName]) { completePresentation(); return; }
        if (!Config.island.screenCapture) { completePresentation(); return; }
        acquiringBackdrop = true; Host.beginCapture();
        captureHidesIsland = kind !== "center";
        Host.backdrop(screenName, null);
        backgroundCapture.live = false;
        backgroundCapture.captureSource = null;
        fadeIn.stop();
        island.opacity = 1;
        // Notification Center is already hidden until Host.prepared commits it.
        // Its acquisition must leave the collapsed Island and banners intact.
        if (captureHidesIsland) fadeOut.restart();
        else acquire.restart();
    }
    function completePresentation() {
        acquire.stop(); fadeOut.stop();
        if (acquiringBackdrop) { Host.endCapture(); acquiringBackdrop = false; }
        backgroundCapture.live = false;
        if (captureHidesIsland) fadeIn.restart();
        const kind = pendingKind, value = pendingValue; pendingKind = "";
        if (kind) Host.prepared(win.screenName,kind,value);
    }
    NumberAnimation {
        id: fadeOut
        target: island; property: "opacity"; to: 0
        duration: Theme.reduced ? 1 : 32
        easing.type: Easing.InQuad
        onFinished: if (win.acquiringBackdrop) acquire.restart()
    }
    // Submit two fully transparent frames before asking the compositor for pixels.
    Timer { id: acquire; interval: 32; onTriggered: { if (!win.acquiringBackdrop) return; backgroundCapture.captureSource = win.screen; } }
    NumberAnimation {
        id: fadeIn
        target: island; property: "opacity"; to: 1
        duration: Theme.reduced ? 1 : 80
        easing.type: Easing.OutQuad
    }
    ScreencopyView {
        id: backgroundCapture; anchors.fill: parent; paintCursor: false; live: false
        onHasContentChanged: if (hasContent && win.acquiringBackdrop) {
            Host.backdrop(win.screenName, desktopTexture);
            win.completePresentation();
        }
    }
    ShaderEffectSource {
        id: desktopTexture
        width: win.width; height: win.height
        sourceItem: backgroundCapture
        hideSource: true; visible: false; live: true; mipmap: true
    }
    Timer { interval: 700; running: win.acquiringBackdrop; onTriggered: win.completePresentation() }
    Connections { target: Host
        function onPrepareRequested(screen,kind,value) { if (screen === win.screenName) win.prepare(kind,value); }
        function onPreparationCancelled() { win.pendingKind = ""; if (win.acquiringBackdrop) win.completePresentation(); }
    }
    Component.onDestruction: { Host.unregisterWindow(win); Host.backdrop(win.screenName, null); if (acquiringBackdrop) Host.endCapture(); }

    MouseArea { id: outsideDismiss; anchors.fill: parent; visible: win.dismissableOpen && (!Host.canGrab || !win.explicitOpen); z: 0; onPressed: Hub.dismiss() }
    // ── Notification Center backdrop: dims + (via the blur layerrule) frosts the desktop ──
    Rectangle {
        id: scrim
        anchors.fill: parent
        z: 1
        // above the 0.35 ignore_alpha threshold → Hyprland blurs the whole screen behind it
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.46) : Qt.rgba(0.08, 0.08, 0.1, 0.40)
        opacity: win.centerShown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 220; easing.type: Config.island.easing } }
        MouseArea { anchors.fill: parent; onClicked: Notifs.centerOpen = false }
    }

    NotificationCenter {
        id: center
        z: 2
        shown: win.centerShown
        screenName: win.screenName
        maxHeight: win.height - y - 16
        x: Math.round((win.width - width) / 2)
        y: Config.island.topMargin + 52
    }

    // Banners sit *under* the island so they appear to drop out of it
    BannerStack {
        id: banners
        z: 5
        active: Config.island.notifStyle !== "island" && win.focusedHere && !win.centerShown
        readonly property bool corner: Config.island.notifStyle === "corner"
        width: corner ? 370 : 400
        x: corner ? win.width - width - 14 : Math.round((win.width - width) / 2)
        y: corner ? (Config.island.overlayBar ? 48 : 10) : island.y + island.height + 10
        originY: corner ? 0 : -(island.height + 10)
        Behavior on y { enabled: !banners.corner; SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.15) } }
    }

    Island {
        id: island
        z: 10
        screenName: win.screenName
        x: Math.round((win.width - width) / 2)
        y: Config.island.topMargin
    }
}
