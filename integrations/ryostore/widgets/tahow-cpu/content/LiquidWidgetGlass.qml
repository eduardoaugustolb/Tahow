import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
Item {
 id:root
 property var settings:({})
 property var screen:null
 property color tint:"#172131"
 property real radius:24
 property bool enabledMaterial:false
 property string wallpaper:""
 readonly property var output:screen || (Quickshell.screens.length ? Quickshell.screens[0] : null)
 function number(key,fallback,min,max){const value=Number(settings[key]);return Number.isFinite(value)?Math.max(min,Math.min(max,value)):fallback;}
 readonly property bool ready:background.status === Image.Ready
 readonly property real outputWidth:output ? output.width : 1920
 readonly property real outputHeight:output ? output.height : 1080
 Socket {
  id:subscription
  path:(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")+"/ryogami.sock"
  connected:root.enabledMaterial
  onConnectionStateChanged:if(connected){write("subscribe wallpaper\n");flush();}
  parser:SplitParser{onRead:line=>{
   try{const frame=JSON.parse(line);const entry=frame.outputs && root.output && frame.outputs[root.output.name] || frame.default;if(entry&&entry.path)root.wallpaper="file://"+entry.path+"?v="+Number(entry.revision||0);}catch(_){}
  }}
 }
 Timer{interval:3000;repeat:true;running:root.enabledMaterial&&!subscription.connected;onTriggered:subscription.connected=true}
 Image {
  id:background
  width:root.outputWidth;height:root.outputHeight
  source:root.enabledMaterial?root.wallpaper:""
  sourceSize:Qt.size(width,height)
  fillMode:Image.PreserveAspectCrop
  asynchronous:true;visible:false;cache:true
 }
 ShaderEffectSource{id:texture;sourceItem:background;live:root.enabledMaterial;visible:false;hideSource:false;mipmap:true}
 NativeGlass {
  anchors.fill:parent;visible:root.enabledMaterial&&root.ready
  src:texture
  sourceRect:{
   let ancestor=root;while(ancestor){ancestor.x;ancestor.y;ancestor.width;ancestor.height;ancestor.scale;ancestor=ancestor.parent;}
   if(root.Window.window){root.Window.window.x;root.Window.window.y;}
   const p=root.mapToGlobal(0,0),end=root.mapToGlobal(root.width,root.height);
   const originX=root.output?root.output.x:0,originY=root.output?root.output.y:0;
   return Qt.rect((p.x-originX)/root.outputWidth,(p.y-originY)/root.outputHeight,(end.x-p.x)/root.outputWidth,(end.y-p.y)/root.outputHeight);
  }
  topLeftRadius:root.radius;topRightRadius:root.radius;bottomLeftRadius:root.radius;bottomRightRadius:root.radius
  tintColor:root.tint;tintAmount:Math.max(0,Math.min(1,Number(root.settings.glassOpacity)||0.55))*0.28
  bezel:root.number("bezel",14,0,40)
  thickness:root.number("thickness",24,0,60)
  ior:root.number("ior",1.5,1,2.5)
  dispersion:root.number("dispersion",0.08,0,0.2)
  frost:root.number("frost",8,0,30)/5
  rim:root.settings.glassRim===false?0:0.25
 }
 Rectangle{anchors.fill:parent;radius:root.radius;color:root.tint;opacity:root.ready?Math.max(0.05,Math.min(1,Number(root.settings.glassOpacity)||0.55))*0.45:0}
}
