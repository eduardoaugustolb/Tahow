import QtQuick
import Quickshell
Item {
    property var modelData: null
    // Ryostore creates a scene per output. Only the primary owns this runtime.
    Loader {
        active: modelData && Quickshell.screens.length && modelData.name === Quickshell.screens[0].name
        sourceComponent: Item {
            Loader { source: "adapters/Ryoku.qml" }
            Runtime { ownsLock: false }
        }
    }
}
