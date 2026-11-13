import QtQuick
import QtQuick.Controls
import "../lib/github.js" as Github
import "../lib/symbols.js" as Symbols
Item {
 id:root
 property var settings:({})
 property color ink:"white"
 property color accent:"#9fc9ff"
 property color muted:"#a5a5ab"
 property var translate: function(key){return key;}
 property bool active:true
 property int year:new Date().getFullYear()
 readonly property string user:Github.username(settings.username)
 property var rawCalendar:({cells:[],total:0,weeks:0})
 readonly property var displayed:Github.windowed(rawCalendar,settings.minWeeks,settings.maxWeeks,width,height-38)
 onDisplayedChanged:{cells=displayed.cells;weeks=displayed.weeks;}
 property var cells:[]
 property int weeks:53
 property int total:0
 property string status:""
 property string selected:""
 property bool loading:false
 property var request:null
 property int generation:0
 function fetch(){
  generation++;const current=generation;
  if(request){request.abort();request=null;}
  if(!active || !user){cells=[];total=0;status=translate("Set your GitHub username in widget settings");loading=false;return;}
  loading=true;status=translate("Loading contributions…");
  const xhr=new XMLHttpRequest();request=xhr;
  xhr.open("GET","https://github-contributions-api.jogruber.de/v4/"+encodeURIComponent(user)+"?y="+year);
  xhr.onreadystatechange=function(){if(xhr.readyState!==XMLHttpRequest.DONE||current!==generation)return;timeout.stop();loading=false;request=null;
   if(xhr.status!==200){status=translate("Unable to load contributions");return;}
   try{const result=Github.calendar(JSON.parse(xhr.responseText),year);rawCalendar=result;total=result.total;status="";}catch(error){status=translate("Unable to load contributions");}
  };xhr.send();timeout.restart();
 }
 onUserChanged:refresh.restart()
 onYearChanged:{selected="";refresh.restart();}
 onActiveChanged:if(active)refresh.restart();else if(request){generation++;request.abort();request=null;loading=false;}
 Component.onCompleted:refresh.restart()
 Component.onDestruction:if(request)request.abort()
 Timer{id:refresh;interval:80;onTriggered:root.fetch()}
 Timer{id:timeout;interval:15000;onTriggered:{root.generation++;if(root.request)root.request.abort();root.request=null;root.loading=false;root.status=root.translate("Unable to load contributions");}}
 Timer{interval:1800000;repeat:true;running:root.active;onTriggered:root.fetch()}
 component GlassButton: Button {
  id:control
  property string symbol: "refresh"
  width:28;height:28
  background:Rectangle { radius:9; color:Qt.rgba(root.ink.r,root.ink.g,root.ink.b,control.hovered ? 0.16 : 0.07);border.width:control.activeFocus?1:0;border.color:root.accent }
  contentItem:Item {Image{anchors.centerIn:parent;width:15;height:15;source:Symbols.image(control.symbol,false,root.ink.toString());sourceSize:Qt.size(30,30);opacity:control.enabled?0.9:0.3}}
 }
 Row {
  id:header;width:parent.width;height:28;spacing:6
  Text {width:Math.max(80,parent.width-310);anchors.verticalCenter:parent.verticalCenter;text:root.user||"GitHub";color:root.ink;font.family:"Inter";font.pixelSize:12;font.weight:Font.DemiBold;elide:Text.ElideRight}
  GlassButton{symbol:"chevron_left";enabled:!root.loading&&root.year>2008;onClicked:root.year--}
  Text{width:36;anchors.verticalCenter:parent.verticalCenter;text:root.year;color:root.ink;font.family:"Inter";font.pixelSize:12;horizontalAlignment:Text.AlignHCenter}
  GlassButton{symbol:"chevron_right";enabled:!root.loading&&root.year<new Date().getFullYear();onClicked:root.year++}
  Text{width:130;anchors.verticalCenter:parent.verticalCenter;text:root.total+" "+root.translate("contributions");color:root.muted;font.family:"Inter";font.pixelSize:11;elide:Text.ElideRight}
  GlassButton{symbol:"refresh";enabled:!root.loading;onClicked:root.fetch();Accessible.name:root.translate("Refresh")}
 }
 Item {
  id:grid;x:0;y:38;width:parent.width;height:Math.max(35,parent.height-y-(root.status ? 18 : 0))
  readonly property real gap:3
  readonly property real cell:Math.max(1,Math.min((width-(root.weeks-1)*gap)/root.weeks,(height-6*gap)/7))
  readonly property real cellHeight:cell
  readonly property real columnGap:root.weeks > 1 ? Math.max(gap,(width-root.weeks*cell)/(root.weeks-1)) : 0
  Repeater{model:root.cells;Rectangle{id:day;required property var modelData;required property int index
   x:Math.floor(index/7)*(grid.cell+grid.columnGap);y:(index%7)*(grid.cellHeight+grid.gap);width:grid.cell;height:grid.cellHeight;radius:Math.min(3,width/4)
   visible:!!modelData.date
   color:Qt.rgba(root.accent.r,root.accent.g,root.accent.b,0.08+modelData.level*0.21)
   border.width:hover.hovered?1:0;border.color:root.ink
   HoverHandler{id:hover;onHoveredChanged:if(hovered)root.selected=day.modelData.date+" · "+day.modelData.count+" "+root.translate("contributions")}
   ToolTip.visible:hover.hovered;ToolTip.text:modelData.date+": "+modelData.count
  }}
 }
 Text{anchors.bottom:parent.bottom;width:parent.width;text:root.status;color:root.muted;font.family:"Inter";font.pixelSize:10;elide:Text.ElideRight}
}
