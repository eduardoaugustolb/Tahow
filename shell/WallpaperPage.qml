import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell.Io
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property color ink
    required property color secondary
    required property color paper
    required property color accent
    property url selectedImage: ""
    property string mode: Config.s.desktopWallpaperMode
    readonly property string currentImage: Theme.desktopWallpaper
    readonly property string wallpaperDirectory: Theme.home("~/Pictures/Wallpapers")
    property int directoryExitCode: -1
    readonly property bool directoryReady: directoryExitCode === 0

    Process {
        running: true
        command: ["mkdir", "-p", "--", root.wallpaperDirectory]
        onExited: code => root.directoryExitCode = code
    }

    FolderListModel {
        id: wallpapers
        folder: root.directoryReady ? Theme.wallpaperUrl(root.wallpaperDirectory) : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.tif", "*.tiff"]
        showDirs: false
        caseSensitive: false
        sortCaseSensitive: false
    }

    Rectangle {
        id: previewFrame
        readonly property int inset: 8
        readonly property real screenAspect: Screen.width > 0 && Screen.height > 0
            ? Screen.width / Screen.height : 16 / 9

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: (290 - 2 * inset) * screenAspect + 2 * inset
        implicitHeight: Math.max(0, width - 2 * inset) / screenAspect + 2 * inset
        radius: 12
        color: root.paper
        clip: true
        Image {
            id: preview
            anchors.fill: parent
            anchors.margins: previewFrame.inset
            asynchronous: true
            sourceSize.width: Math.round(width * 2)
            fillMode: root.mode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            source: root.selectedImage.toString() || Theme.wallpaperUrl(root.currentImage)
            Accessible.name: I18n.tr("Wallpaper preview")
        }
        Txt {
            anchors.centerIn: parent
            visible: preview.status === Image.Null || preview.status === Image.Error
            sourceText: preview.status === Image.Error ? "Could not preview this image" : "No wallpaper to preview"
            color: root.secondary
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Row {
            spacing: 3
            Accessible.name: I18n.tr("Wallpaper placement")
            Repeater {
                model: ["Fill screen", "Fit to screen"]
                ActionButton {
                    required property int index
                    required property string modelData
                    text: I18n.tr(modelData)
                    checkable: true
                    checked: root.mode === (index === 0 ? "crop" : "fit")
                    enabled: !DesktopWallpaper.busy
                    autoExclusive: true
                    onClicked: root.mode = index === 0 ? "crop" : "fit"
                }
            }
        }
        Item { Layout.fillWidth: true }
        ActionButton {
            primary: true
            text: I18n.tr("Apply wallpaper")
            enabled: !DesktopWallpaper.busy && preview.status === Image.Ready
            onClicked: DesktopWallpaper.apply(preview.source.toString(), root.mode)
        }
    }

    Txt {
        Layout.fillWidth: true
        sourceText: DesktopWallpaper.status
        color: root.ink
        wrapMode: Text.WordWrap
        visible: text !== ""
    }

    RowLayout {
        Layout.fillWidth: true
        Txt {
            Layout.fillWidth: true
            text: root.wallpaperDirectory
            color: root.secondary
            elide: Text.ElideMiddle
        }
        ActionButton {
            text: I18n.tr("Open wallpapers folder")
            enabled: root.directoryReady
            onClicked: Qt.openUrlExternally(Theme.wallpaperUrl(root.wallpaperDirectory))
        }
    }

    Txt {
        Layout.fillWidth: true
        visible: root.directoryExitCode > 0 || (root.directoryReady && wallpapers.status === FolderListModel.Ready && wallpapers.count === 0)
        sourceText: root.directoryReady ? "Add images to the wallpapers folder to see them here."
            : "Could not open the wallpapers folder"
        color: root.secondary
        wrapMode: Text.WordWrap
    }

    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(3, Math.ceil(count / columns)) * cellHeight
        visible: root.directoryReady && count > 0
        readonly property int columns: Math.max(1, Math.floor(width / 126))
        cellWidth: Math.floor(width / columns)
        cellHeight: 96
        clip: true
        model: wallpapers
        currentIndex: -1
        keyNavigationEnabled: true
        Accessible.name: I18n.tr("Wallpaper")
        ScrollBar.vertical: SettingsControls.Bar {}
        delegate: Button {
            id: tile
            required property url fileUrl
            required property string fileName
            width: grid.cellWidth - 6
            height: grid.cellHeight - 6
            padding: 3
            Accessible.name: fileName
            readonly property bool selected: fileUrl.toString() === preview.source.toString()
            Accessible.selectable: true
            Accessible.selected: selected
            onClicked: root.selectedImage = fileUrl
            background: Rectangle {
                radius: 7
                color: tile.selected || tile.visualFocus ? root.accent : root.paper
            }
            contentItem: Image {
                source: tile.fileUrl
                sourceSize.width: 240
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                clip: true
            }
        }
    }

    component ActionButton: Button {
        id: button
        property bool primary: false
        implicitHeight: 34
        horizontalPadding: 12
        contentItem: Text {
            text: button.text
            color: !button.enabled ? root.secondary
                : button.primary || button.checked ? (Theme.lum(root.accent) > 0.6 ? "#182233" : "#ffffff") : root.ink
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
        background: Rectangle {
            radius: 7
            color: button.enabled && (button.primary || button.checked) ? root.accent
                : button.hovered ? Theme.alpha(root.ink, 0.10) : root.paper
            border.color: button.activeFocus ? root.accent : "transparent"
        }
    }
}
