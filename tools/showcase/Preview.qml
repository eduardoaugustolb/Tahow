import QtQuick
import QtQuick.Window
import Quickshell
import "./shell" as Tahow
import "./shell/lock" as Lock
import "./widgets/content" as Widgets
import "./widgets/service" as Services

ShellRoot {
    id: root
    readonly property string mode: Quickshell.env("TAHOW_PREVIEW")
    QtObject {
        id: simulatedAuthentication
        property string user: "Tahow"
        property bool fingerprintReady: false
        property string fingerprintState: "unavailable"
        signal loginFailed()
        signal loginSucceeded()
        function login() { throw new Error("Authentication is disabled in screenshot previews"); }
    }
    QtObject {
        id: notificationFixture
        property string focusedOutput: "eDP-1"
        property int workspace: 9
        property var occupied: [9]
        property bool focusGrabAvailable: false
        property var notifications: [
            {id:9001,appName:"Tahow",appIcon:"dialog-information",summary:"Showcase atualizado",body:"Novas capturas com mídia ativa e capas de álbum.",actions:[],hints:{},image:"",urgency:1,transient:false},
            {id:9002,appName:"Música",appIcon:"audio-x-generic",summary:"Reprodução em andamento",body:"A ilha e o widget acompanham o player MPRIS.",actions:[],hints:{},image:"",urgency:1,transient:false}
        ]
        function removePopup() {}
        function fullscreen() { return false; }
    }
    Window {
        id: window
        width: 1920; height: 1080; visible: true
        Item {
            id: canvas
            anchors.fill: parent
            Image { anchors.fill:parent;source:Tahow.Theme.wallpaper ? "file://"+Tahow.Theme.wallpaper : "";fillMode:Image.PreserveAspectCrop }
            Rectangle { anchors.fill:parent;color:"#20000000" }
            Loader {
                anchors.fill:parent
                active:root.mode === "lockscreen"
                sourceComponent:Lock.LockView {authentication:simulatedAuthentication}
            }
            Loader {
                anchors.fill:parent
                active:root.mode === "widgets"
                sourceComponent:Item {
                    Repeater {
                        model:["cpu","temperature","disk","memory","session","clock","media","github"]
                        Item {
                            id: tile
                            required property int index
                            required property string modelData
                            x:index<4 ? 276+index*348 : index===4 ? 276 : index===5 ? 648 : index===6 ? 900 : 276
                            y:index<4 ? 170 : index===7 ? 690 : 390
                            width:index<4 ? 324 : index===4 ? 340 : index===5 ? 220 : index===6 ? 720 : 1340
                            height:index<4 ? 180 : index===7 ? 220 : 240
                            QtObject {id:api;property var mainInstance:service;property var pluginSettings:({appearance:"dark",language:"pt-BR",material:"liquid",username:"eduardoaugustolb",minWeeks:20,maxWeeks:53});property string pluginDir:Qt.resolvedUrl("widgets").toString().replace(/^file:\/\//,"")}
                            Services.WidgetService {id:service;kind:tile.modelData;pluginApi:api}
                            Widgets.WidgetFace {anchors.fill:parent;kind:tile.modelData;pluginApi:api;screen:Quickshell.screens[0];s:1.15}
                        }
                    }
                }
            }
            Loader {
                anchors.centerIn:parent
                active:root.mode === "notifications"
                sourceComponent:Tahow.NotificationCenter {shown:true;screenName:"eDP-1";maxHeight:900}
            }
            Loader {
                x:parent.width/2-width/2;y:20
                active:root.mode === "media-peek"
                sourceComponent:Tahow.Island {screenName:"eDP-1";peek:true}
            }
        }
        Timer {
            interval:6000;running:true
            onTriggered:canvas.grabToImage(result=>{
                if(!result.saveToFile(Quickshell.env("TAHOW_OUTPUT")))console.error("Failed to save preview");
                Qt.quit();
            })
        }
    }
    Component.onCompleted:if(mode === "notifications")Tahow.Host.adapter=notificationFixture
}
