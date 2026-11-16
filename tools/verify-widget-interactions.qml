import QtQuick
import Quickshell
import "../integrations/widgets/content"
ShellRoot {
    id: root
    property var calls: []
    QtObject {
        id:fake
        property string username:"Test User"
        property string trackTitle:"Synthetic track"
        property string trackArtist:"Synthetic artist"
        property string trackArtUrl:""
        property real position:0
        property real length:180
        property bool isPlaying:true
        property bool canControl:true
        property bool canSeek:true
        property bool canTogglePlaying:true
        property bool canGoPrevious:true
        property bool canGoNext:true
        property bool positionSupported:true
        property bool lengthSupported:true
        function session(action){root.calls=root.calls.concat([action]);}
        function togglePlaying(){root.calls=root.calls.concat(["toggle"]);}
        function previous(){root.calls=root.calls.concat(["previous"]);}
        function next(){root.calls=root.calls.concat(["next"]);}
        function seek(value){root.calls=root.calls.concat(["seek"]);}
    }
    QtObject {id:api;property var mainInstance:fake;property var pluginSettings:({appearance:"dark"})}
    FloatingWindow {visible:true;implicitWidth:350;implicitHeight:220;WidgetFace{id:face;anchors.fill:parent;kind:"session";pluginApi:api}}
    WidgetFace { id:mediaFace; kind:"media"; pluginApi:api; visible:false }
    Timer {interval:100;running:true;onTriggered:{
        if(root.calls.length)throw new Error("Action executed at construction");
        mediaFace.service.togglePlaying();
        if(root.calls.join()!=="toggle")throw new Error("Media play/pause action was not delivered");
        root.calls=[];
        face.requestAction("reboot");if(root.calls.length)throw new Error("Restart lacked confirmation");
        face.requestAction("reboot");if(root.calls.join()!=="reboot")throw new Error("Restart confirmation failed");
        face.requestAction("poweroff");if(root.calls.length!==1)throw new Error("Shutdown lacked confirmation");
        face.pendingAction="";face.requestAction("lock");if(root.calls.join()!=="reboot,lock")throw new Error("Explicit lock failed");
        face.kind="clock";api.pluginSettings=({});
        if(face.bareClock || face.liquidMaterial)throw new Error("Legacy material changed");
        if(face.implicitHeight!==220 || face.unit!==1)throw new Error("Natural size depends on rendered height");
        api.pluginSettings=({clockStyle:"bare"});if(!face.bareClock)throw new Error("Bare clock variant failed");
        api.pluginSettings=({clockStyle:"bare",material:"liquid"});if(!face.liquidMaterial || face.bareClock)throw new Error("Opt-in liquid variant failed");
        face.settingsOpen=true;
        if(!face.settingsCreated)throw new Error("Preferences were not created");
        finish.start();
    }}
    Timer {id:finish;interval:100;onTriggered:{
        face.settingsOpen=false;
        if(!face.settingsCreated)throw new Error("Closing destroyed pending preference writes");
        console.log("WIDGET_INTERACTIONS_OK media-action-and-session-controls");Qt.quit();
    }}
}
