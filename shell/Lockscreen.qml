import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "lock"
Scope {
    id: root
    property bool requested: false
    readonly property bool secure: session.secure
    QtObject {
        id: authentication
        readonly property string user: Quickshell.env("USER")
        readonly property string fingerprintState: "unavailable"
        readonly property bool fingerprintReady: false
        property string pending: ""
        signal loginFailed()
        signal loginSucceeded()
        function login(userName, password, index) {
            if (pam.active) return;
            pending = password;
            if (!pam.start()) { pending = ""; loginFailed(); }
        }
    }
    PamContext {
        id: pam; user: authentication.user; config: Config.s.pamService
        onResponseRequiredChanged: if (responseRequired) {
            if (authentication.pending) { const secret = authentication.pending; authentication.pending = ""; respond(secret); }
            else { abort(); authentication.loginFailed(); }
        }
        onCompleted: result => {
            authentication.pending = "";
            if (result === PamResult.Success) { authentication.loginSucceeded(); session.unlock(); root.requested = false; }
            else authentication.loginFailed();
        }
        onError: { authentication.pending = ""; authentication.loginFailed(); }
    }
    WlSessionLock {
        id: session
        locked: root.requested
        WlSessionLockSurface {
            color: Theme.window
            LockView { anchors.fill: parent; authentication: authentication }
        }
    }
    IpcHandler { target: "tahoeLock"; function lock(): void { if (Config.s.lockscreenEnabled) root.requested = true; } }
}
