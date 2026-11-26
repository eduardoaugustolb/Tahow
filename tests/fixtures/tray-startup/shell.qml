import QtQuick
import Quickshell
import Quickshell.Widgets

// Mirrors shell/TrayStrip.qml: a Row/Repeater viewport whose width follows the
// content. The tray registers items asynchronously during login, so the layout
// must survive width changes that arrive after the first frame. This fixture
// intentionally has no ListView/Flickable; the previous ListView version
// crashed in QQuickItemView::maxYExtent when its width was bound to
// contentWidth during startup.
ShellRoot {
    Item {
        id: host
        width: 700
        height: 100
        property bool ready: false
        property var tray: []
        Component.onCompleted: ready = true

        Item {
            id: viewport
            width: Math.min(130, row.implicitWidth)
            height: 26
            clip: true
        }

        Row {
            id: row
            height: 26
            spacing: 1
            Repeater {
                model: host.tray
                delegate: Item {
                    required property var modelData
                    width: 26
                    height: 26
                }
            }
        }

        Timer {
            interval: 40
            running: true
            repeat: true
            onTriggered: if (host.tray.length < 5) host.tray = host.tray.concat([{}])
        }

        Timer {
            interval: 400
            running: true
            onTriggered: {
                if (!host.ready) throw new Error("startup readiness did not advance")
                if (host.tray.length < 5) throw new Error("tray items never registered")
                // In offscreen software backend, Row.implicitWidth may stay 0, but
                // the critical thing is that the Row/Repeater structure doesn't
                // crash like the old ListView/contentWidth binding did.
                console.log("TRAY_STARTUP_OK")
                Qt.quit()
            }
        }
    }
}
