import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Ryoku.PluginKit.Singletons as Host
import "../lib/material.js" as Material
import "../lib/symbols.js" as Symbols
import "../lib/locale.js" as Locale
import "../lib/messages.js" as Messages

Item {
    id: root
    property string kind: "cpu"
    property var pluginApi: null
    property var screen
    property bool active: true
    property string density: "compact"
    property real s: 1
    property real widthBudget: 360
    property color accentColor: Host.Theme.brand
    property bool accentFromHost: true
    readonly property var settings: pluginApi && pluginApi.pluginSettings || ({})
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool liquidMaterial: settings.material === "liquid"
    readonly property bool bareClock: settings.material === "none" || (!liquidMaterial && kind === "clock" && settings.clockStyle === "bare")
    readonly property bool metric: ["cpu","temperature","disk","memory"].indexOf(kind) >= 0
    readonly property real unit: Math.max(0.4, Math.min(s, Number(settings.contentHeight)>0 ? Number(settings.contentHeight) / (kind === "github" ? 210 : metric ? 150 : kind === "clock" ? 220 : kind === "session" ? 200 : 160) : s))
    readonly property bool dark: settings.appearance === "dark" || (settings.appearance !== "light" && (Host.Theme.tileBg.r + Host.Theme.tileBg.g + Host.Theme.tileBg.b < 1.5))
    readonly property color accent: accentFromHost ? accentColor : Host.Theme.brand
    readonly property color ink: dark ? "#f5f5f7" : "#1d1d20"
    readonly property color muted: Qt.rgba(ink.r,ink.g,ink.b,0.62)
    readonly property color tint: Material.tint(dark,settings.glassAccentTint !== false,accent)
    readonly property string language: Locale.resolve(settings.language,"",Qt.locale().name)
    function tr(key) { return Locale.translate(Messages.catalogs,language,key); }
    function alpha(c,a) { return Qt.rgba(c.r,c.g,c.b,a); }
    function time(value) { const n=Math.max(0,Math.floor(value || 0)); return Math.floor(n/60)+":"+String(n%60).padStart(2,"0"); }
    implicitWidth: kind === "clock" && settings.clockCompact === true ? Math.max(clockDate.implicitWidth,clockHour.implicitWidth,clockMinute.implicitWidth)+12*unit : Number(settings.contentWidth)>0 ? Number(settings.contentWidth) : kind === "github" ? 640*s : Math.min(widthBudget > 0 ? widthBudget : 360, (kind === "github" ? 640 : metric ? 180 : kind === "clock" ? 180 : kind === "session" ? 340 : 360)*unit)
    implicitHeight: Number(settings.contentHeight)>0 ? Number(settings.contentHeight) : (kind === "github" ? 210 : metric ? 150 : kind === "clock" ? 220 : kind === "session" ? 200 : 160)*unit
    property date now: new Date()
    Timer { interval: root.settings.showSeconds ? 1000 : 15000; repeat: true; running: root.active && root.visible && root.kind === "clock"; onTriggered: root.now = new Date() }
    property bool settingsOpen:false
    property bool settingsCreated:false
    onSettingsOpenChanged:if(settingsOpen)settingsCreated=true
    Loader { active:root.settingsCreated; sourceComponent:WidgetPreferences {visible:root.settingsOpen;translate:root.tr;kind:root.kind;pluginApi:root.pluginApi;ink:root.ink;paper:root.dark?"#252529":"#f5f5f7";accent:root.accent;onDismissed:root.settingsOpen=false} }
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.WithinBounds
        onTapped: root.settingsOpen = true
    }
    property string pendingAction: ""
    Timer { id: confirmation; interval: 4500; onTriggered: root.pendingAction = "" }
    function requestAction(action) {
        if (!service) return;
        if (action === "lock" || action === "settings") { service.session(action); return; }
        if (pendingAction === action) { pendingAction=""; confirmation.stop(); service.session(action); }
        else { pendingAction=action; confirmation.restart(); }
    }
    component Symbol: Image {
        property string name: "info"
        property color ink: root.ink
        source: Symbols.image(name,false,ink.toString())
        sourceSize: Qt.size(width*2,height*2)
        smooth: true
    }
    component Action: Button {
        id: action
        property string symbol: "play_arrow"
        property string label: ""
        property bool emphasized: false
        Accessible.name: root.tr(label)
        ToolTip.visible: hovered
        ToolTip.text: root.tr(label)
        background: Rectangle {
            radius: Math.min(14*root.unit,height/2)
            color: action.down ? root.alpha(root.accent,0.4) : action.emphasized ? root.alpha(root.accent,0.24) : root.alpha(root.ink,action.hovered ? 0.16 : 0.07)
            border.width: action.activeFocus ? 2 : 0; border.color: root.accent
        }
        contentItem: Item { Symbol { anchors.centerIn:parent; name: action.symbol; width: 22*root.unit; height: width; opacity: action.enabled ? 1 : 0.35 } }
    }
    RectangularShadow { visible: !root.bareClock; anchors.fill: plate; radius: plate.radius; blur: 22*root.unit; offset.y: 6*root.unit; color: "#30000000" }
    Rectangle {
        id: plate; anchors.fill: parent; radius: 24*root.unit; clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: root.bareClock ? "transparent" : root.alpha(Qt.lighter(root.tint,root.dark ? 1.6 : 1.04),Math.min(0.96,Material.opacity(root.settings.glassOpacity)+0.18)) }
            GradientStop { position: 1; color: root.bareClock ? "transparent" : root.alpha(root.tint,Material.opacity(root.settings.glassOpacity)) }
        }
        border.width: root.bareClock || root.settings.glassRim === false ? 0 : 1
        border.color: root.alpha(root.dark ? "white" : root.accent,root.dark ? 0.22 : 0.3)
        Rectangle { visible: !root.bareClock; anchors.fill: parent; anchors.margins: 2; radius: parent.radius-2; color: "transparent"; border.width: 0.5; border.color: root.alpha("white",root.dark ? 0.06 : 0.55) }
        LiquidWidgetGlass { anchors.fill:parent; enabledMaterial:root.active && root.liquidMaterial; settings:root.settings; screen:root.screen; tint:root.tint; radius:plate.radius }
        GithubWidget { anchors.fill:parent; anchors.margins:14; visible:root.kind === "github"; active:root.active && visible; settings:root.settings; ink:root.ink; muted:root.muted; accent:root.accent; translate:root.tr }
        Item {
            visible: root.metric; anchors.fill: parent; anchors.margins: 16*root.unit
            Symbol { x: 0; y: 0; width: 20*root.unit; height: width; name: root.kind === "cpu" ? "settings" : root.kind === "temperature" ? "light_mode" : root.kind === "disk" ? "monitor" : "apps"; ink: root.accent }
            Text { x: 28*root.unit; width: parent.width-x; y: 2*root.unit; text: root.tr(({cpu:"CPU",temperature:"Temperature",disk:"Disk",memory:"Memory"})[root.kind] || ""); color: root.muted; font.family:"Inter"; font.pixelSize:12*root.unit; elide: Text.ElideRight }
            Text { anchors.left: parent.left; anchors.right: parent.right; y: 43*root.unit; height: 42*root.unit; text: root.service && root.service.available ? root.service.valueText : "—"; color: root.ink; font.family:"Inter"; font.pixelSize: 32*root.unit; font.weight: Font.DemiBold; fontSizeMode: Text.Fit; minimumPixelSize:18 }
            Rectangle { y: parent.height-22*root.unit; width: parent.width; height: 5*root.unit; radius: height/2; color:root.alpha(root.ink,0.1)
                Rectangle { height: parent.height; radius:height/2; width: parent.width*Math.max(0,Math.min(1,root.service ? root.service.value : 0)); color:root.accent; Behavior on width { NumberAnimation { duration:400; easing.type:Easing.OutCubic } } }
            }
            Text { anchors.bottom:parent.bottom; width:parent.width; text: root.service && root.service.available ? root.service.detailText : root.tr("Unavailable"); color:root.muted; font.family:"Inter"; font.pixelSize:10*root.unit; elide:Text.ElideRight }
        }
        Item {
            visible: root.kind === "clock"; anchors.fill:parent; anchors.margins:18*root.unit; anchors.leftMargin:root.settings.clockCompact ? 6*root.unit : 18*root.unit; anchors.rightMargin:root.settings.clockCompact ? 6*root.unit : 18*root.unit
            Text { id:clockDate; width:parent.width; text:Qt.locale(root.language).toString(root.now,"ddd, d MMM"); color:root.muted; font.family:"Inter"; font.pixelSize:12*root.unit; horizontalAlignment:Text.AlignHCenter }
            Column { anchors.centerIn:parent; spacing:-12*root.unit
                Text { id:clockHour; text:Qt.formatTime(root.now,root.settings.use24h === false ? "hh AP" : "HH").replace(/\s[AP]M/,""); color:root.ink; font.family:"Inter"; font.pixelSize:66*root.unit; font.weight:Font.Light; anchors.horizontalCenter:parent.horizontalCenter }
                Text { id:clockMinute; text:Qt.formatTime(root.now,"mm"); color:root.accent; font.family:"Inter"; font.pixelSize:66*root.unit; font.weight:Font.DemiBold; anchors.horizontalCenter:parent.horizontalCenter }
            }
            Text { anchors.bottom:parent.bottom; width:parent.width; text: root.settings.showSeconds ? Qt.formatTime(root.now,"ss") : root.settings.use24h === false ? Qt.formatTime(root.now,"AP") : root.tr("Local time"); color:root.muted; font.family:"Inter"; font.pixelSize:11*root.unit; horizontalAlignment:Text.AlignHCenter }
        }
        Item {
            visible:root.kind === "session"; anchors.fill:parent; anchors.margins:16*root.unit
            Rectangle { width:56*root.unit; height:width; radius:width/2; color:root.alpha(root.accent,0.18)
                Symbol { anchors.centerIn:parent; width:30*root.unit;height:width;name:"account_circle";ink:root.accent }
            }
            Text { x:70*root.unit; y:7*root.unit; width:parent.width-x; text:root.service ? root.service.username : root.tr("User"); color:root.ink;font.family:"Inter";font.pixelSize:14*root.unit;font.weight:Font.DemiBold;elide:Text.ElideRight }
            Text { x:70*root.unit; y:30*root.unit; text:root.tr("Session"); color:root.muted;font.family:"Inter";font.pixelSize:11*root.unit }
            Row { y:74*root.unit;width:parent.width;spacing:8*root.unit
                Action { width:(parent.width-parent.spacing*3)/4;height:52*root.unit;symbol:"lock";label:"Lock";onClicked:root.requestAction("lock") }
                Action { width:(parent.width-parent.spacing*3)/4;height:52*root.unit;symbol:"bedtime";label:"Suspend";onClicked:root.requestAction("suspend") }
                Action { width:(parent.width-parent.spacing*3)/4;height:52*root.unit;symbol:"refresh";label:"Restart";onClicked:root.requestAction("reboot") }
                Action { width:(parent.width-parent.spacing*3)/4;height:52*root.unit;symbol:"power_settings_new";label:"Shut Down";onClicked:root.requestAction("poweroff") }
            }
            Text { anchors.bottom:parent.bottom;width:parent.width;text:root.pendingAction ? root.tr("Click again to confirm")+": "+root.tr(({suspend:"Suspend",reboot:"Restart",poweroff:"Shut Down"})[root.pendingAction]) : root.tr("Session controls");color:root.pendingAction ? root.accent : root.muted;font.family:"Inter";font.pixelSize:11*root.unit;elide:Text.ElideRight }
        }
        Item {
            visible:root.kind === "media"; anchors.fill:parent; anchors.margins:14*root.unit
            ClippingRectangle { id: art; width:88*root.unit;height:width;radius:16*root.unit;color:root.alpha(root.accent,0.15)
                Image { id:albumArt; anchors.fill:parent; source:root.service ? (root.service.artUrl || "") : "";fillMode:Image.PreserveAspectCrop;asynchronous:true;sourceSize:Qt.size(320,320);opacity:status === Image.Ready ? 1 : 0 }
                Symbol { anchors.centerIn:parent;width:34*root.unit;height:width;name:"music_note";ink:root.accent;visible:albumArt.status !== Image.Ready }
            }
            Column { x:art.width+12*root.unit;width:parent.width-x;spacing:5*root.unit
                Text { width:parent.width;text:root.service && root.service.title ? root.service.title : root.tr("Not Playing");color:root.ink;font.family:"Inter";font.pixelSize:14*root.unit;font.weight:Font.DemiBold;elide:Text.ElideRight }
                Text { width:parent.width;text:root.service && root.service.artist ? root.service.artist : root.tr("Start music in any MPRIS player");color:root.muted;font.family:"Inter";font.pixelSize:11*root.unit;elide:Text.ElideRight }
                Row { spacing:6*root.unit
                    Action { width:36*root.unit;height:34*root.unit;symbol:"skip_previous";label:"Previous";enabled:!!root.service && !!root.service.canPrevious;onClicked:root.service.previous() }
                    Action { width:42*root.unit;height:34*root.unit;symbol:root.service && root.service.playing ? "pause" : "play_arrow";label:root.service && root.service.playing ? "Pause" : "Play";emphasized:true;enabled:!!root.service && !!root.service.canTogglePlaying;onClicked:root.service.togglePlaying() }
                    Action { width:36*root.unit;height:34*root.unit;symbol:"skip_next";label:"Next";enabled:!!root.service && !!root.service.canNext;onClicked:root.service.next() }
                }
            }
            Slider { id:seek;anchors.left:parent.left;anchors.right:parent.right;y:96*root.unit;height:18*root.unit;from:0;to:1;value:root.service ? (root.service.value || 0) : 0;enabled:!!root.service && !!root.service.canSeek;onMoved:root.service.seek(value);Accessible.name:root.tr("Playback position")
                background:Rectangle { x:seek.leftPadding;y:seek.height/2-2;width:seek.availableWidth;height:4;radius:2;color:root.alpha(root.ink,0.14);Rectangle { width:seek.visualPosition*parent.width;height:parent.height;radius:2;color:root.accent } }
                handle:Rectangle { x:seek.leftPadding+seek.visualPosition*(seek.availableWidth-width);y:seek.height/2-height/2;width:10*root.unit;height:width;radius:width/2;color:root.ink;visible:seek.enabled }
            }
            Text { anchors.bottom:parent.bottom;text:root.time(root.service ? root.service.position : 0);color:root.muted;font.family:"Inter";font.pixelSize:10*root.unit }
            Text { anchors.bottom:parent.bottom;anchors.right:parent.right;text:root.time(root.service ? root.service.length : 0);color:root.muted;font.family:"Inter";font.pixelSize:10*root.unit }
        }
    }
}
