pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Ryoku.Ui.Singletons
import shell.services

// Tahow notification banner. A self-contained liquid-glass popup card running
// under Ryoku's notification host: it never creates a window (the host owns
// position/spacing/lifetime) and reaches only global modules for tokens, icons
// and Notifs, staying inside the design sandbox.
Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    readonly property real pad: 14 * us
    readonly property bool dark: true
    readonly property color ink: dark ? "#f2f4f8" : "#16181d"
    readonly property color inkDim: dark ? "rgba(242,244,248,0.66)" : "rgba(22,24,29,0.66)"
    readonly property color glassFill: dark ? "rgba(18,20,26,0.66)" : "rgba(252,252,254,0.70)"
    readonly property color glassRim: dark ? "rgba(255,255,255,0.26)" : "rgba(255,255,255,0.54)"
    readonly property color accent: "#0a84ff"

    readonly property var visibleActions: {
        const source = root.notification?.actions || [];
        const result = [];
        for (let i = 0; i < source.length; ++i) {
            const candidate = source[i];
            if (candidate && candidate.identifier !== "default"
                    && String(candidate.text || "").length > 0)
                result.push(candidate);
        }
        return result;
    }
    readonly property var defaultAction: {
        const source = root.notification?.actions || [];
        for (let i = 0; i < source.length; ++i) {
            if (source[i] && source[i].identifier === "default")
                return source[i];
        }
        return null;
    }
    readonly property string pictureSource: showImages
        ? String(root.notification?.image || "") : ""

    implicitHeight: content.implicitHeight + pad * 2

    function invokeAndDismiss(action): void {
        if (action && typeof action.invoke === "function")
            action.invoke();
        Notifs.dismiss(root.notification);
    }

    Rectangle {
        anchors.fill: parent
        radius: 20 * root.us
        gradient: Gradient {
            GradientStop { position: 0; color: root.dark ? "#c9282a32" : "#d9ffffff" }
            GradientStop { position: 0.48; color: root.glassFill }
            GradientStop { position: 1; color: root.glassFill }
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 8 * root.us

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.us

            Rectangle {
                readonly property string rawIcon: String(root.notification?.appIcon || "")
                Layout.preferredWidth: 26 * root.us
                Layout.preferredHeight: 26 * root.us
                radius: 8 * root.us
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                visible: rawIcon !== ""
                Image {
                    anchors.fill: parent
                    anchors.margins: 4 * root.us
                    source: parent.rawIcon === "" ? ""
                        : parent.rawIcon.indexOf("/") >= 0 || parent.rawIcon.indexOf(":") >= 0
                            ? parent.rawIcon : Icons.path(parent.rawIcon, true)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.notification?.appName || I18n.tr("Notification")
                color: root.inkDim
                font.family: Tokens.ui
                font.pixelSize: 12 * root.us
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 26 * root.us
                Layout.preferredHeight: 26 * root.us
                radius: 13 * root.us
                color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("Close")
                Accessible.onPressAction: Notifs.dismiss(root.notification)
                Image {
                    anchors.centerIn: parent
                    width: 16 * root.us
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: "assets/close.svg"
                }
                HoverHandler { id: closeHover }
                TapHandler { onTapped: Notifs.dismiss(root.notification) }
            }
        }

        Image {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 140 * root.us : 0
            visible: root.pictureSource !== ""
            source: root.pictureSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            clip: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3 * root.us

            Text {
                Layout.fillWidth: true
                text: root.notification?.summary || ""
                color: root.ink
                font.family: Tokens.ui
                font.pixelSize: 14 * root.us
                font.weight: Font.DemiBold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            Text {
                Layout.fillWidth: true
                visible: String(root.notification?.body || "").length > 0
                text: root.notification?.body || ""
                textFormat: Text.StyledText
                color: root.inkDim
                font.family: Tokens.ui
                font.pixelSize: 12.5 * root.us
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            TapHandler {
                enabled: root.defaultAction !== null
                onTapped: root.invokeAndDismiss(root.defaultAction)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6 * root.us
            visible: root.visibleActions.length > 0

            Repeater {
                model: root.visibleActions

                delegate: Rectangle {
                    id: actionButton
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34 * root.us
                    radius: 12 * root.us
                    color: actionHover.hovered || actionTap.pressed
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                        : Qt.rgba(1, 1, 1, root.dark ? 0.06 : 0.55)
                    border.width: Math.max(1, root.us)
                    border.color: root.glassRim

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16 * root.us
                        horizontalAlignment: Text.AlignHCenter
                        text: actionButton.modelData.text
                        color: root.ink
                        font.family: Tokens.ui
                        font.pixelSize: 12.5 * root.us
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    HoverHandler { id: actionHover }
                    TapHandler {
                        id: actionTap
                        onTapped: root.invokeAndDismiss(actionButton.modelData)
                    }
                }
            }
        }
    }
}
