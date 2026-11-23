pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// System tray icons for the expanded island header. The viewport stays
// independent of contentWidth because tray items register asynchronously
// during startup and Qt Quick recalculates Flickable extents when its width
// changes.
Item {
    id: root
    property real maxWidth: 130
    property real iconSize: 16
    property int collapsedMax: 3
    readonly property int count: SystemTray.items.values.length
    readonly property real slotSize: 26
    readonly property real spacing: 1
    readonly property bool overflow: count > collapsedMax
    readonly property bool open: hov.hovered || !overflow
    signal activated()

    implicitHeight: slotSize
    implicitWidth: Math.min(maxWidth, Math.min(row.implicitWidth, collapsedMax * (slotSize + spacing) - spacing)
        + (overflow && !open ? moreChip.width + 2 : 0))

    HoverHandler { id: hov }

    Item {
        id: viewport
        width: Math.min(root.maxWidth, row.implicitWidth)
        height: parent.height
        clip: true

        Row {
            id: row
            height: parent.height
            spacing: root.spacing
            x: root.open ? 0 : Math.min(0, viewport.width - root.collapsedMax * (root.slotSize + root.spacing) + root.spacing)
            opacity: hov.hovered ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: slot
                    required property SystemTrayItem modelData
                    width: root.slotSize
                    height: root.slotSize

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.fill2
                        opacity: ma.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: root.iconSize
                        source: slot.modelData ? slot.modelData.icon : ""
                        scale: ma.pressed ? 0.85 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                    }

                    function openMenu() {
                        if (!modelData.hasMenu) return;
                        const p = slot.mapToItem(null, 0, slot.height + 6);
                        modelData.display(QsWindow.window, Math.round(p.x), Math.round(p.y));
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const it = slot.modelData;
                            if (m.button === Qt.RightButton) { slot.openMenu(); return; }
                            if (m.button === Qt.MiddleButton) { it.secondaryActivate(); root.activated(); return; }
                            if (it.onlyMenu) { slot.openMenu(); return; }
                            it.activate();
                            root.activated();
                        }
                        onWheel: w => {
                            const horiz = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y);
                            slot.modelData.scroll(horiz ? w.angleDelta.x : w.angleDelta.y, horiz);
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: moreChip
        visible: root.overflow && !root.open
        anchors.left: viewport.right
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        width: moreTxt.implicitWidth + 10
        radius: 9
        color: Theme.fill2
        opacity: 0.8
        Txt { id: moreTxt; anchors.centerIn: parent; sourceText: "+" + (root.count - root.collapsedMax); size: 10; weight: Font.DemiBold; color: Theme.fg2 }
    }
}
