// SPDX-License-Identifier: AGPL-3.0-only
// Geometry-only bridge. No pixels, captures or wallpaper cross this socket.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
Item {
    id: root
    property bool active: true
    property bool discoverWhileHidden: false
    readonly property bool wantsConnection: active && instance.length > 0 && geometry.supported && (discoverWhileHidden || (geometry.alpha > 0 && geometry.clipWidth > 0 && geometry.clipHeight > 0))
    property string target: "quickshell:island"
    property real radius: 20
    property real bezel: 14
    property real thickness: 24
    property real ior: 1.5
    property real dispersion: 0.08
    property real frost: 8
    property real innerShadow: 1
    property real rim: 1
    property bool prism: false
    readonly property bool surfaceLocal: target === "tahow-settings"
    function position(item, x, y) {
        return surfaceLocal && root.Window.window ? item.mapToItem(root.Window.window.contentItem, x, y) : item.mapToGlobal(x, y);
    }
    readonly property bool available: socket.connected && protocolReady
    readonly property bool materialAvailable: available && (!prism || prismSupported)
    property bool prismSupported: false
    readonly property bool ready: active && materialAvailable && presented && geometry.supported && geometry.clipWidth > 0 && geometry.clipHeight > 0
    property bool protocolReady: false
    property bool presented: false
    property bool queued: false
    readonly property string token: "glass-" + Date.now() + "-" + Math.random().toString(36).slice(2)
    readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/hypr/" + instance + "/tahow-glass.sock"
    // QQuickItem.transform is non-notifiable. Cache its object references only
    // from imperative lifecycle callbacks; bindings observe those objects' fields.
    property var cachedAncestorTransforms: []
    readonly property var ancestry: {
        const items = [];
        let item = root;
        while (item) { items.push(item); item = item.parent; }
        return items;
    }
    function refreshTransformReferences() {
        const entries = [];
        for (const item of ancestry) {
            const transforms = [];
            for (const transform of item.transform) transforms.push(transform);
            entries.push({item:item, transforms:transforms});
        }
        cachedAncestorTransforms = entries;
    }
    onAncestryChanged: Qt.callLater(root.refreshTransformReferences)
    onParentChanged: Qt.callLater(root.refreshTransformReferences)
    Component.onCompleted: refreshTransformReferences()
    readonly property var geometry: {
        let a = root, alpha = 1, shown = root.active, supported = true;
        const clips = [];
        while (a) {
            // Read transform members explicitly so QML tracks their notifications.
            // Calling mapToGlobal alone does not subscribe to Translate/Scale.
            a.x; a.y; a.width; a.height; a.scale;
            if (Math.abs(a.rotation) > 0.0001) supported = false;
            const cached = cachedAncestorTransforms.find(entry => entry.item === a);
            if (!cached) supported = false;
            for (const transform of cached ? cached.transforms : []) {
                let known = false;
                if ("x" in transform) { transform.x; transform.y; known = true; }
                if ("z" in transform && Math.abs(transform.z) > 0.0001) supported = false;
                if ("xScale" in transform) {
                    transform.xScale; transform.yScale;
                    if (transform.xScale <= 0 || transform.yScale <= 0) supported = false;
                    known = true;
                }
                if ("origin" in transform) { transform.origin.x; transform.origin.y; transform.origin.z; }
                if ("angle" in transform) {
                    // Native regions are axis-aligned; preserve the QML fallback
                    // rather than drawing a rotated surface's bounding box.
                    if (Math.abs(transform.angle) > 0.0001) supported = false;
                    known = true;
                }
                if ("matrix" in transform) { transform.matrix; supported = false; known = true; }
                if (!known) supported = false;
            }
            alpha *= a.opacity;
            shown = shown && a.visible;
            if (a.clip) {
                const p = root.position(a, 0, 0), q = root.position(a, a.width, a.height);
                clips.push({left:p.x, top:p.y, right:q.x, bottom:q.y});
            }
            a = a.parent;
        }
        if (root.Window.window) { root.Window.window.x; root.Window.window.y; shown = shown && root.Window.window.visible; }
        const start = root.position(root, 0, 0), end = root.position(root, root.width, root.height);
        let left = start.x, top = start.y, right = end.x, bottom = end.y;
        for (const clip of clips) {
            left = Math.max(left, clip.left); top = Math.max(top, clip.top);
            right = Math.min(right, clip.right); bottom = Math.min(bottom, clip.bottom);
        }
        return {op:"region",id:token,target:target,surfaceLocal:surfaceLocal,prism:prism,rim:rim,innerShadow:innerShadow,screen:root.Window.window && root.Window.window.screen ? root.Window.window.screen.name : "",x:start.x,y:start.y,width:Math.max(0,end.x-start.x),height:Math.max(0,end.y-start.y),radius:radius * Math.max(0, Math.min((end.x-start.x)/Math.max(1,root.width),(end.y-start.y)/Math.max(1,root.height))),bezel:bezel,thickness:thickness,ior:ior,dispersion:dispersion,frost:frost,alpha:shown && supported ? alpha : 0,supported:supported,clipX:left,clipY:top,clipWidth:Math.max(0,right-left),clipHeight:Math.max(0,bottom-top)};
    }
    function send(value) { if (socket.connected) { socket.write(JSON.stringify(value) + "\n"); socket.flush(); } }
    function publish() {
        queued = false;
        if (!available) return;
        if (!active || !materialAvailable || !geometry.supported || geometry.alpha <= 0 || geometry.width < 1 || geometry.height < 1 || geometry.clipWidth <= 0 || geometry.clipHeight <= 0) { presented = false; send({op:"remove",id:token}); }
        else send(geometry);
    }
    function schedule() { if (!queued) { queued = true; Qt.callLater(root.publish); } }
    onGeometryChanged: schedule()
    onAvailableChanged: { if (available) schedule(); else presented = false; }
    Socket {
        id: socket
        path: root.socketPath
        connected: root.wantsConnection
        onConnectionStateChanged: {
            root.protocolReady = false; root.prismSupported = false; root.presented = false;
            if (connected) root.send({op:"hello",version:1});
        }
        parser: SplitParser { onRead: line => {
            try {
                const message = JSON.parse(line);
                if (message.op === "hello") {
                    root.prismSupported = message.prism === true;
                    root.protocolReady = message.version === 1 && message.provider === "hyprland-acrylic";
                }
                if (message.op === "presented" && message.id === root.token) root.presented = true;
            } catch (_) {}
        } }
    }
    // Only retry discovery; geometry and rendering never use a polling timer.
    Timer { interval: 3000; repeat: true; running: root.wantsConnection && !socket.connected; onTriggered: socket.connected = Qt.binding(() => root.wantsConnection) }
    Component.onDestruction: send({op:"remove",id:token})
}
