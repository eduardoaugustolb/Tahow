import QtQuick
import Quickshell
import Quickshell.Io
import "content"
import "service"
ShellRoot {
    id: root
    property var faces: []
    property var kinds: ["cpu","temperature","disk","memory","session","clock","media"]
    PanelWindow {
        id: window
        color: "#122135"
        anchors { top:true;left:true }
        implicitWidth: 1000; implicitHeight: 620
        Rectangle { anchors.fill:parent;gradient:Gradient { GradientStop {position:0;color:"#122b48"} GradientStop {position:1;color:"#070e1b"} } }
        Repeater {
            model: root.kinds
            Item {
                id: tile
                required property string modelData
                required property int index
                x: index < 4 ? 30+index*200 : index === 4 ? 30 : index === 5 ? 400 : 610
                y: index < 4 ? 30 : 230
                width: face.implicitWidth;height:face.implicitHeight
                WidgetService { id:data;kind:tile.modelData;pluginApi:api }
                QtObject { id:api;property var mainInstance:data;property string pluginDir:Qt.resolvedUrl(".").toString().replace(/^file:\/\//,"");property var pluginSettings:({material:"liquid",appearance:"dark",language:"pt-BR",refreshInterval:2,username:"eduardoaugustolb"}) }
                WidgetFace { id:face;kind:tile.modelData;pluginApi:api;anchors.fill:parent;accentColor:"#9fc9ff"
                    Component.onCompleted: { const next=root.faces.slice();next[tile.index]=face;root.faces=next; }
                }
            }
        }
    }
    Timer { interval:3500;running:true;onTriggered:{for(let i=0;i<root.faces.length;i++){const kind=root.kinds[i];root.faces[i].grabToImage(result=>result.saveToFile(Qt.resolvedUrl("assets/preview-"+kind+".png").toString().replace(/^file:\/\//,"")));} } }
    IpcHandler {target:"widgetPreview";function close():void{Qt.quit();}}
}
