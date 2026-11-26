import ".." as Tahow
import QtCore
import QtQuick
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import Qt.labs.folderlistmodel

RowLayout {
    id: root
    spacing: 12

    readonly property url home: StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property Tahow.SettingsControls.Colors tones: Tahow.SettingsControls.Colors {}
    readonly property url parentFolder: {
        const current = folder.toString().replace(/\/+$/, "");
        return current.startsWith("file:///") ? current.slice(0, Math.max("file:///".length, current.lastIndexOf("/"))) : "";
    }
    readonly property int entryCount: folders.count
    property url folder: home
    property bool openFailed: false

    function navigate(url) {
        openFailed = false;
        folder = url;
        listing.currentIndex = 0;
        listing.positionViewAtBeginning();
    }

    FolderListModel {
        id: folders
        // shortcut: Qt's FolderListModel parses the decoded local path again, remove when Qt preserves URL escapes.
        folder: root.folder.toString().replace(/%(23|3F|25)/gi, "%25$1")
        showDirsFirst: true
        sortCaseSensitive: false
    }

    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 138
        radius: 12
        color: root.tones.base

        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 5
            spacing: 2

            Repeater {
                model: [
                    {label: "Home", url: root.home, icon: "home"},
                    {label: "Desktop", url: StandardPaths.writableLocation(StandardPaths.DesktopLocation), icon: "monitor"},
                    {label: "Documents", url: StandardPaths.writableLocation(StandardPaths.DocumentsLocation), icon: "description"},
                    {label: "Downloads", url: StandardPaths.writableLocation(StandardPaths.DownloadLocation), icon: "download"},
                    {label: "Pictures", url: StandardPaths.writableLocation(StandardPaths.PicturesLocation), icon: "image"}
                ]

                FileRow {
                    required property var modelData
                    readonly property bool current: root.folder.toString() === modelData.url.toString()
                    width: parent.width
                    text: Tahow.I18n.tr(modelData.label)
                    iconName: modelData.icon
                    selected: current
                    onClicked: root.navigate(modelData.url)
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Basic.Label {
                Layout.fillWidth: true
                text: decodeURIComponent(root.folder.toString().replace(/^file:\/\//, ""))
                color: root.tones.placeholderText
                font.family: Tahow.Theme.font
                font.pixelSize: 13
                elide: Text.ElideMiddle
            }

            Tahow.SettingsControls.Button {
                text: Tahow.I18n.tr("Parent folder")
                enabled: root.parentFolder.toString() !== ""
                    && root.parentFolder.toString() !== root.folder.toString()
                onClicked: root.navigate(root.parentFolder)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: root.tones.base

            ListView {
                id: listing
                anchors.fill: parent
                anchors.margins: 5
                boundsBehavior: Flickable.StopAtBounds
                activeFocusOnTab: true
                clip: true
                model: folders
                Keys.onReturnPressed: currentItem?.open()
                Keys.onEnterPressed: currentItem?.open()
                Basic.ScrollBar.vertical: Basic.ScrollBar {}

                delegate: FileRow {
                    id: entry
                    required property string fileName
                    required property url fileUrl
                    required property bool fileIsDir
                    text: fileName
                    width: listing.width
                    iconName: fileIsDir ? "folder" : "description"
                    selected: ListView.isCurrentItem && listing.activeFocus
                    focusPolicy: Qt.ClickFocus
                    rightPadding: 18

                    function open() {
                        if (fileIsDir) root.navigate(fileUrl);
                        else root.openFailed = !Qt.openUrlExternally(fileUrl);
                    }

                    onClicked: open()
                }
            }

            Basic.Label {
                anchors.centerIn: parent
                visible: folders.status === FolderListModel.Ready && root.entryCount === 0
                text: Tahow.I18n.tr("Empty folder")
                color: root.tones.placeholderText
                font.family: Tahow.Theme.font
            }
        }

        Basic.Label {
            Layout.fillWidth: true
            visible: root.openFailed
            text: Tahow.I18n.tr("Could not open this file")
            color: root.tones.windowText
            font.family: Tahow.Theme.font
        }
    }

    component FileRow: Basic.ItemDelegate {
        id: row
        required property string iconName
        property bool selected: false
        height: 38
        leftPadding: 10
        rightPadding: 8
        Accessible.name: text

        contentItem: RowLayout {
            spacing: 8
            Tahow.Icon {
                size: 17
                text: row.iconName
                color: row.selected ? root.tones.highlight : root.tones.placeholderText
            }
            Basic.Label {
                Layout.fillWidth: true
                text: row.text
                color: root.tones.windowText
                font.family: Tahow.Theme.font
                font.pixelSize: 13
                elide: Text.ElideMiddle
            }
        }

        background: Rectangle {
            radius: 8
            color: row.down || row.hovered || row.selected ? Tahow.Theme.alpha(root.tones.highlight, 0.14) : "transparent"
            border.width: row.visualFocus ? 2 : 0
            border.color: root.tones.highlight
        }
    }
}
