pragma Singleton
import QtQuick
import Quickshell

// Passive album-art tint state shared by the core theme. A media service
// (the Hub in the full shell) populates it; without one, "album" accent
// sources degrade to the default instead of pulling in the media stack.
Singleton {
    property color color: "#0a84ff"
    property bool valid: false
    property bool playing: false
}