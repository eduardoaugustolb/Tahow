import QtQuick
import Quickshell
import "../integrations/widgets/content"
ShellRoot {
    id: root
    property var calls: []
    QtObject { id:fake;property string username:"Test User";function session(action){root.calls=root.calls.concat([action]);} }
    QtObject {id:api;property var mainInstance:fake;property var pluginSettings:({appearance:"dark"})}
    FloatingWindow {visible:true;implicitWidth:350;implicitHeight:220;WidgetFace{id:face;anchors.fill:parent;kind:"session";pluginApi:api}}
    Timer {interval:100;running:true;onTriggered:{
        if(root.calls.length)throw new Error("Action executed at construction");
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
        console.log("WIDGET_INTERACTIONS_OK");Qt.quit();
    }}
}
