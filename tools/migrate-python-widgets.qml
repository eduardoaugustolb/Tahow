import QtQuick
import Quickshell
ShellRoot {
 property var controller:null
 Component.onCompleted:{controller=Qt.createQmlObject('import QtQuick; import "file://' + (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + '/quickshell/shell/modules/desktop/Singletons" as Desktop; QtObject { function disable(monitor) { Desktop.Config.setManyFor(monitor, {pythonCpuEnabled:false,pythonTempEnabled:false,pythonDiskEnabled:false,pythonRamEnabled:false,pythonUserEnabled:false,pythonTimeEnabled:false,pythonMusicEnabled:false,pythonGithubEnabled:false}); } }',this);}
 Timer{interval:500;running:true;onTriggered:{controller.disable(Quickshell.env("TAHOW_MIGRATION_MONITOR") || "eDP-1");}}
 Timer{interval:1400;running:true;onTriggered:Qt.quit()}
}
