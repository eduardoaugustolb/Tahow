import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
FloatingWindow {
 id:win
 property string kind:"cpu"
 property var pluginApi:null
 property color ink:"#f5f5f7"
 property color paper:"#252529"
 property color accent:"#9fc9ff"
 property var translate:function(key){return key;}
 property var schema:[]
 property var patch:({})
 property var pending:({})
 property bool hadFocus:false
 Connections {
  target: win.contentItem.Window.window
  function onActiveChanged(){
   if(target.active)win.hadFocus=true;
   else if(win.visible && win.hadFocus)win.dismissed();
  }
 }
 readonly property var settings:pluginApi && pluginApi.pluginSettings || ({})
 signal dismissed()
 title:"Tahow · "+kind
 implicitWidth:620;implicitHeight:700
 minimumSize:Qt.size(620,700);maximumSize:Qt.size(620,700)
 visible:true;color:paper
 onVisibleChanged:{
  if(!visible){hadFocus=false;dismissed();}
  else {patch=({});hadFocus=false;Qt.callLater(function(){if(win.visible && win.contentItem.Window.window)win.contentItem.Window.window.requestActivate();});}
 }
 function current(field){return patch[field.key] !== undefined?patch[field.key]:settings[field.key] !== undefined?settings[field.key]:field.default;}
 function save(field,value){
  const next=Object.assign({},patch);next[field.key]=value;patch=next;
  const queue=Object.assign({},pending);queue[field.key]=value;pending=queue;delay.restart();
 }
 FileView{path:win.pluginApi&&win.pluginApi.pluginDir?win.pluginApi.pluginDir+"/manifest.json":"";printErrors:false;onLoaded:{try{win.schema=JSON.parse(text()).metadata.settings||[];}catch(_){}}}
 Timer{id:delay;interval:150;onTriggered:win.flush()}
 function flush(){if(writer.running||!Object.keys(pending).length)return;writer.command=["ryoku-plugins-place","tahow-"+kind,"settings",JSON.stringify(pending)];pending=({});writer.running=true;}
 Process{id:writer;onExited:win.flush()}
 Shortcut{sequence:"Escape";onActivated:win.dismissed()}
 Column {
  anchors.fill:parent;anchors.margins:22;spacing:14
  Row{width:parent.width;height:38
   Text{width:parent.width-40;text:win.title;color:win.ink;font.family:"Inter";font.pixelSize:20;font.weight:Font.DemiBold}
   Button{width:36;height:32;text:"×";onClicked:win.dismissed()}
  }
  ScrollView{width:parent.width;height:parent.height-60;contentWidth:availableWidth;clip:true
   Column{width:parent.width;spacing:12
    Repeater{model:win.schema
     Column{id:field;required property var modelData;required property int index;readonly property var spec:modelData;readonly property var value:win.current(spec);width:parent.width;spacing:6
      Text{visible:field.index===0||win.schema[field.index-1].group!==field.spec.group;text:win.translate(field.spec.group||"");color:win.accent;font.family:"Inter";font.pixelSize:13;topPadding:12}
      Row{width:parent.width;height:field.spec.type==="slider"?24:38
       Text{width:parent.width-230;text:win.translate(field.spec.label);color:win.ink;font.family:"Inter";font.pixelSize:13;anchors.verticalCenter:parent.verticalCenter;elide:Text.ElideRight}
       Loader{width:230;height:parent.height;sourceComponent:field.spec.type==="toggle"?toggle:field.spec.type==="choice"?choice:field.spec.type==="slider"?amount:entry}
      }
      Slider{visible:field.spec.type==="slider";width:parent.width;from:Number(field.spec.min)||0;to:Number(field.spec.max)||1;stepSize:Number(field.spec.step)||0.01;value:Number(field.value);onMoved:win.save(field.spec,value)}
      Component{id:toggle;Switch{checked:field.value===true;onToggled:win.save(field.spec,checked)}}
      Component{id:choice;ComboBox{model:field.spec.options;currentIndex:field.spec.options.findIndex(option=>option.value===field.value);textRole:"label";valueRole:"value";displayText:currentIndex>=0?win.translate(field.spec.options[currentIndex].label):"";delegate:ItemDelegate{required property var modelData;width:230;text:win.translate(modelData.label)} onActivated:index=>win.save(field.spec,field.spec.options[index].value)}}
      Component{id:amount;Text{text:Number(field.value).toFixed(3);color:win.ink;font.family:"Inter";font.pixelSize:12;horizontalAlignment:Text.AlignRight}}
      Component{id:entry;TextField{text:String(field.value??"");color:win.ink;selectByMouse:true;onEditingFinished:{if(field.spec.type==="int"){const number=Number(text);if(Number.isFinite(number))win.save(field.spec,Math.max(field.spec.min??-Infinity,Math.min(field.spec.max??Infinity,Math.round(number))));}else win.save(field.spec,text);}}}
     }
    }
   }
  }
 }
}
