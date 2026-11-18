import QtQuick
import "lib/backdrop.js" as Backdrop
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
    // Keep every overlay child out of the initial output snapshot.
    contentItem.opacity: presentationReady ? 1 : 0

    readonly property bool centerShown: Notifs.centerOpen && Notifs.centerScreen === screenName
    readonly property bool explicitOpen: island.isExpanded || centerShown
    readonly property bool dismissableOpen: island.isExpanded || island.peek || centerShown
    readonly property bool snapshotStable: island.isExpanded || island.isLauncher || centerShown || island.peek || banners.hovered
    function layoutDump() {
        return Object.assign(island.layoutDump(), {
            screen: screenName,
            islandOpacity: island.opacity,
            surfaceOpacity: win.contentItem.opacity,
            acquiringBackdrop: acquiringBackdrop,
            presentationReady: presentationReady,
            captureHasContent: backgroundCapture.hasContent,
            liveBackdropAvailable: compositorProbe.available,
            backdropReady: !!Host.backdrops[screenName]
        });
    }
    Component.onCompleted: { Host.registerWindow(win); warmup.restart(); }
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


    CompositorGlass {
        id: compositorProbe
        discoverWhileHidden: true
        active: Config.island.screenCapture && Theme.glass
        onAvailableChanged: if (available && !win.presentationReady) {
            backgroundCapture.captureSource = null;
            win.completePresentation();
        }
    }
    property bool snapshotReleased: false
    function snapshotConsumersReady(item, inheritedOpacity) {
        const effectiveOpacity = inheritedOpacity * item.opacity;
        if (!item.visible || effectiveOpacity <= 0) return true;
        if ("snapshotFallbackNeeded" in item && item.width > 0 && item.height > 0 && item.snapshotFallbackNeeded) return false;
        for (const child of item.children) {
            if (!snapshotConsumersReady(child, effectiveOpacity)) return false;
        }
        return true;
    }
    readonly property bool canReleaseSnapshot: !snapshotReleased && presentationReady && !acquiringBackdrop
        && island.compositorReady && snapshotConsumersReady(win.contentItem, 1)
    onCanReleaseSnapshotChanged: if (canReleaseSnapshot) {
        // Every currently visible consumer has submitted its native replacement.
        // Keep the snapshot while any sibling still needs its QML fallback.
        Host.backdrop(win.screenName, null);
        snapshotReleased = true;
        backgroundCapture.captureSource = null;
    }
    property bool acquiringBackdrop: false
    property bool presentationReady: false
    property string pendingKind: ""
    property int pendingValue: 0
    function prepare(kind,value) {
        pendingKind = kind; pendingValue = value;
        if (acquiringBackdrop || !presentationReady) return;
        completePresentation();
    }
    // Capture one clean output frame before presentation. Keep it stable across
    // pill states so the material never samples its own overlay.
    function prepareBackdrop() {
        if (presentationReady || acquiringBackdrop) return;
        if (compositorProbe.available) { completePresentation(); return; }
        if (!Config.island.screenCapture || !Theme.glass || !Host.desktopCaptureAllowed) { completePresentation(); return; }
        if (!Host.desktopCaptureReady) return;
        acquiringBackdrop = true; Host.beginCapture();
        backgroundCapture.live = false;
        backgroundCapture.captureSource = null;
        acquire.restart();
    }
    function completePresentation() {
        acquire.stop();
        if (acquiringBackdrop) { Host.endCapture(); acquiringBackdrop = false; }
        backgroundCapture.live = false;
        presentationReady = true;
        const kind = pendingKind, value = pendingValue; pendingKind = "";
        if (kind) Host.prepared(win.screenName,kind,value);
    }
    Timer { id: warmup; interval: 0; onTriggered: win.prepareBackdrop() }
    // Give the overlay a transparent frame before capturing the output.
    Timer { id: acquire; interval: 32; onTriggered: { if (!win.acquiringBackdrop) return; backgroundCapture.captureSource = win.screen; } }
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
        sourceItem: win.snapshotReleased ? null : backgroundCapture
        textureSize: { const s = Backdrop.size(win.width, win.height); return Qt.size(s.width, s.height); }
        hideSource: true; visible: false; live: true; mipmap: true
    }
    Timer { interval: 700; running: win.acquiringBackdrop; onTriggered: win.completePresentation() }
    Connections { target: Host
        function onDesktopCaptureReadyChanged() { if (Host.desktopCaptureReady) warmup.restart(); }
        function onPrepareRequested(screen,kind,value) { if (screen === win.screenName) win.prepare(kind,value); }
        function onPreparationCancelled() { win.pendingKind = ""; }
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
        shown: win.presentationReady && win.centerShown
        screenName: win.screenName
        maxHeight: win.height - y - 16
        x: Math.round((win.width - width) / 2)
        y: Config.island.topMargin + 52
    }

    // Banners sit *under* the island so they appear to drop out of it
    BannerStack {
        id: banners
        z: 5
        active: win.presentationReady && Config.island.notifStyle !== "island" && win.focusedHere && !win.centerShown
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
        visible: win.presentationReady
        screenName: win.screenName
        x: Math.round((win.width - width) / 2)
        y: Config.island.topMargin
    }
}
