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
        console.log("WIDGET_INTERACTIONS_OK");Qt.quit();
    }}
}
