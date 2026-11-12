import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import ".."
import "../lib/material.js" as Material

Rectangle {
    id: root
    required property var authentication
    property var sddm: authentication
    property var userModel: null
    property var sessionModel: null
    property var config: ({clock24h: Config.lockscreen.use24h ? "true" : "false"})
    width: Screen.width
    height: Screen.height
    color: Theme.window
    readonly property real s: Math.min(width / 1512, height / 982)
    readonly property bool inSession: typeof sddm !== "undefined" && typeof sddm.fingerprintState !== "undefined"
    readonly property var live: ({motion: Config.lockscreen.motion, wallpaperUrl: Theme.wallpaper ? "file://" + Theme.wallpaper : "", batteryLevel: -1, charging: false})
    readonly property bool darkMaterial: Config.lockscreen.style === "black" || Config.lockscreen.appearance === "dark" || (Config.lockscreen.appearance !== "light" && Theme.autoDark)
    readonly property color materialTint: Config.lockscreen.style === "black" ? "#000000" : Theme.materialTint(Config.lockscreen, darkMaterial)
    property date now: new Date()
    property bool expanded: false
    property bool submitting: false
    property real unlockProgress: 0
    // Same motion table as the installed Dynamic Island Theme.qml.
    readonly property string motionMode: live ? live.motion : "balanced"
    readonly property bool reducedMotion: motionMode === "reduced"
    readonly property real islandSpring: ({gentle: 3.0, balanced: 3.6, bouncy: 4.2, reduced: 7})[motionMode] || 3.6
    readonly property real islandDamping: ({gentle: 0.42, balanced: 0.30, bouncy: 0.21, reduced: 1.0})[motionMode] || 0.30
    property bool revealed: false
    property real fieldHeight: expanded ? 32 * s : 0
    Behavior on fieldHeight {
        enabled: !root.reducedMotion
        SpringAnimation { spring: root.islandSpring * 1.12; damping: Math.min(1, root.islandDamping + 0.06); epsilon: 0.25 }
    }
    property string errorMessage: ""
    readonly property int sessionIndex: sessionModel && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string loginUser: authentication.user
    readonly property bool fingerprintReady: inSession && sddm.fingerprintReady
    readonly property string displayName: userHelper.currentItem ? userHelper.currentItem.displayName : loginUser
    readonly property string avatarUrl: userHelper.currentItem ? userHelper.currentItem.avatarUrl : ""
    readonly property bool clock24h: typeof config === "undefined" || config.clock24h !== "false"

    function submit() {
        if (submitting || !password.text.length || !loginUser.length) return
        errorMessage = ""
        submitting = true
        sddm.login(loginUser, password.text, sessionIndex)
    }

    ListView {
        id: userHelper
        visible: false; width: 1; height: 1
        model: userModel
        currentIndex: userModel ? Math.max(0, userModel.lastIndex) : 0
        delegate: Item {
            required property var model
            property string displayName: model.realName || model.name || root.loginUser
            property string avatarUrl: model.icon || ""
        }
    }
    Timer { interval: 1000; running: root.visible; repeat: true; onTriggered: root.now = new Date() }
    Component.onCompleted: { password.forceActiveFocus(); revealed = true }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            unlockAnimation.stop()
            root.unlockProgress = 0
            root.submitting = false
            root.expanded = true
            root.errorMessage = I18n.tr("Login Failed")
            password.clear()
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() {
            password.clear()
            unlockAnimation.restart()
        }
    }

    // The wallpaper belongs to the desktop, not the theme. No Apple assets.
    Item {
        id: background
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: root.color }
        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.live ? root.live.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
    ShaderEffectSource {
        id: wallpaperTexture; sourceItem: background; hideSource: false
        live: root.visible; visible: false
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#100b1b24" }
            GradientStop { position: 0.6; color: "#000b1b24" }
            GradientStop { position: 1; color: "#380b1b24" }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: { root.expanded = true; password.forceActiveFocus() }
    }
    Column {
        id: clockGroup
        property real entranceOpacity: root.revealed ? 1 : 0
        opacity: entranceOpacity * (1 - root.unlockProgress)
        scale: root.revealed ? 1 : 0.92
        Behavior on entranceOpacity {
            SequentialAnimation {
                PauseAnimation { duration: root.revealed && !root.reducedMotion ? 70 : 0 }
                NumberAnimation { duration: root.reducedMotion ? 1 : (root.revealed ? 280 : 150); easing.type: Config.lockscreen.easing }
            }
        }
        Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 1 : 460; easing.type: Config.lockscreen.easing; easing.overshoot: 1.3 } }
        transform: Translate { y: -36 * root.s * root.unlockProgress }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.088
        spacing: -9 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr(I18n.locale.toString(root.now, "ddd MMM d"))
            color: "#c4efff"; font.family: "Inter"; font.weight: Font.DemiBold
            font.pixelSize: 27 * root.s
        }
        GlassClock {
            anchors.horizontalCenter: parent.horizontalCenter
            backdrop: wallpaperTexture
            scene: root
            s: root.s
            text: Qt.formatTime(root.now, root.clock24h ? "HH:mm" : "h:mm")
        }
    }
    Row {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 16 * root.s; spacing: 14 * root.s
        Text {
            text: I18n.tr(typeof keyboard !== "undefined" && keyboard.capsLock ? "⇪" : "")
            color: "white"; font.pixelSize: 13 * root.s
        }
        Text {
            visible: root.live && root.live.batteryLevel >= 0
            text: I18n.tr(root.live ? (root.live.charging ? "ϟ  " : "") + root.live.batteryLevel + "%" : "")
            color: "#e6f4fa"; font.family: "Inter"; font.pixelSize: 12 * root.s
        }
    }
    Column {
        id: profile
        transformOrigin: Item.Bottom
        scale: Math.max(1,Math.min(1.4,Config.lockscreen.lockFooterScale))
        opacity: 1 - root.unlockProgress
        transform: Translate { y: 22 * root.s * root.unlockProgress }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.84 - (root.expanded ? 35 * root.s : 0)
        width: 300 * root.s; spacing: 11 * root.s
        Behavior on y {
            enabled: !root.reducedMotion
            SpringAnimation { spring: root.islandSpring; damping: root.islandDamping; epsilon: 0.25 }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 50 * root.s; height: width; radius: width / 2
            color: "#9af4bc"
            Text {
                anchors.centerIn: parent
                visible: !avatar.visible
                text: I18n.tr(root.displayName.slice(0, 1).toUpperCase())
                font.family: "Inter"; font.pixelSize: 22 * root.s; font.weight: Font.Medium
                color: "#275442"
            }
            Image {
                id: avatar; anchors.fill: parent; source: root.avatarUrl
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: Rectangle { width: avatar.width; height: avatar.height; radius: width / 2 } }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr(root.displayName)
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            color: "white"; font.family: "Inter"; font.pixelSize: 14 * root.s; font.weight: Font.DemiBold
            style: Text.Raised; styleColor: "#33000000"
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 188 * root.s; height: Math.max(0, root.fieldHeight)
            visible: height > 0; clip: true; radius: 18 * root.s
            color: root.darkMaterial ? "#30101318" : "#18ffffff"; border.color: password.activeFocus ? "#55ffffff" : "#30ffffff"
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 0.92
            Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 1 : (root.expanded ? 280 : 150); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.reducedMotion ? 1 : 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            LiquidGlass {
                anchors.fill: parent
                src: wallpaperTexture
                topLeftRadius: parent.radius; topRightRadius: parent.radius
                bottomLeftRadius: parent.radius; bottomRightRadius: parent.radius
                tintColor: root.materialTint
                tintAmount: Material.amount(Config.lockscreen.lockTint, 0.035); frost: 0.55; rim: Config.lockscreen.lockRim
                ior: Config.lockscreen.lockIor; thickness: (Config.lockscreen.lockThickness) * root.s; bezel: (Config.lockscreen.lockBezel) * root.s
                dispersion: Config.lockscreen.lockDispersion; energy: Config.lockscreen.lockEnergy
                sourceRect: {
                    const point = mapToItem(root, 0, 0)
                    return Qt.rect(point.x / root.width, point.y / root.height, width / root.width, height / root.height)
                }
            }
            TextInput {
                id: password; anchors.fill: parent
                anchors.leftMargin: 13 * root.s; anchors.rightMargin: 34 * root.s
                verticalAlignment: TextInput.AlignVCenter
                color: "white"; font.family: "Inter"; font.pixelSize: 13 * root.s
                echoMode: TextInput.Password; passwordCharacter: "•"; selectByMouse: true
                enabled: !root.submitting; focus: true
                onTextChanged: if (text.length) root.expanded = true
                onAccepted: root.submit()
                Keys.onEscapePressed: { clear(); root.expanded = false; root.errorMessage = "" }
            }
            Text {
                anchors.left: parent.left; anchors.leftMargin: 13 * root.s; anchors.verticalCenter: parent.verticalCenter
                visible: !password.text.length; text: I18n.tr("Password")
                color: "#ddffffff"; font.family: "Inter"; font.pixelSize: 12 * root.s
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 9 * root.s; anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr(root.submitting ? "…" : "➜"); color: "white"; font.pixelSize: 18 * root.s
                MouseArea { anchors.fill: parent; anchors.margins: -6 * root.s; onClicked: root.submit() }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr(root.errorMessage || (root.fingerprintReady ? I18n.tr("Touch sensor or enter password") : I18n.tr("Enter Password")))
            color: root.errorMessage ? "#ffd2cc" : "#e3f2f6"
            font.family: "Inter"; font.pixelSize: 11 * root.s
        }
    }
    // Current qylock closes non-clockwork themes 100 ms after authentication.
    // Finish within that host-owned interval; never delay or fake PAM success.
    NumberAnimation {
        id: unlockAnimation; target: root; property: "unlockProgress"
        from: 0; to: 1; duration: root.reducedMotion ? 1 : 90; easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: profile; property: "anchors.horizontalCenterOffset"; to: -8 * root.s; duration: 55 }
        NumberAnimation { target: profile; property: "anchors.horizontalCenterOffset"; to: 8 * root.s; duration: 80 }
        NumberAnimation { target: profile; property: "anchors.horizontalCenterOffset"; to: 0; duration: 55 }
    }
}
