//@ pragma UseQApplication
import Quickshell
import QtQuick
ShellRoot {
    id: root
    property real t0: Date.now()
    Runtime { ownsLock: false }
    Timer {
        interval: 50; repeat: true; running: true
        property int n: 0
        onTriggered: {
            n++;
            if (n === 1) console.log("TAHOW_FIRST_TIMER_MS " + (Date.now() - root.t0));
            if (n >= 40) { console.log("TAHOW_ALIVE_MS " + (Date.now() - root.t0)); Qt.quit(); }
        }
    }
}
