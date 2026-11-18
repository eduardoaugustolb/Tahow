import QtQuick
import Quickshell
import "./shell" as Tahow
ShellRoot {
 id:root
 property int phase:0
 Tahow.SettingsWindow {id:settings}
 Tahow.CommandPalette {id:palette}
 function walk(item,target){if(item.target===target)return item;for(const child of item.children||[]){const result=walk(child,target);if(result)return result;}return null;}
 Component.onCompleted:{Tahow.Config.set("general","screenCapture",true);Tahow.Config.set("general","style","glass");}
 Timer{interval:100;repeat:true;running:true;onTriggered:{
  if(root.phase===0){const material=root.walk(settings.contentItem,"tahow-settings");if(!material||!material.ready)return;console.log("SETTINGS_NATIVE_OK");settings.visible=false;palette.show();root.phase=1;}
  else {const state=palette.stateDump();if(!state.layout||state.layout.provider!=="compositor-live")return;if(state.layout.captureHasContent){console.error("SURFACES_NATIVE_FAILED: palette retained capture");Qt.exit(1);return;}console.log("PALETTE_NATIVE_OK noCapture=true");palette.hide();Qt.quit();}
 }}
 Timer{interval:8000;running:true;onTriggered:{console.error("SURFACES_NATIVE_FAILED timeout "+JSON.stringify(palette.stateDump()));Qt.exit(1);}}
}
