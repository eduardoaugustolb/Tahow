pragma Singleton
import QtQuick
import Quickshell
Singleton {
    readonly property color paper: Theme.window
    readonly property string ui: Theme.font
    readonly property bool reduceMotion: Theme.reduced
    function px(n) { return n; }
    function dur(n) { return Theme.reduced ? 1 : n * Config.island.fastDuration / 180; }
}
