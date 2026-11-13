import QtQuick
import Quickshell
import Quickshell.Io
import "content"
ShellRoot {
 PanelWindow {
  anchors{top:true;left:true}implicitWidth:700;implicitHeight:260;color:"#102238"
  QtObject{id:api;property var mainInstance:null;property var pluginSettings:({appearance:"dark",language:"pt-BR",username:"eduardoaugustolb",contentWidth:640,contentHeight:210})}
  WidgetFace{id:face;x:24;y:24;width:640;height:210;kind:"github";pluginApi:api;accentColor:"#a8cbff"}
 }
 Timer{interval:5000;running:true;onTriggered:face.grabToImage(result=>result.saveToFile(Qt.resolvedUrl("assets/preview-github.png").toString().replace(/^file:\/\//,"")))}
 IpcHandler{target:"githubPreview";function close():void{Qt.quit();}}
}
