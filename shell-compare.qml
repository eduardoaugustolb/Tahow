import QtQuick
import Quickshell
import "shell"

Item {
    id: root
    implicitWidth: 800
    implicitHeight: 200

    // Shared wallpaper texture - same source for both sides
    Item {
        id: wallpaperRef
        width: root.implicitWidth
        height: root.implicitHeight
        Image {
            anchors.fill: parent
            source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
        Rectangle {
            anchors.fill: parent
            visible: !Theme.wallpaper
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a1a2e" }
                GradientStop { position: 1; color: "#16213e" }
            }
        }
    }
    ShaderEffectSource { id: wallpaperTex; sourceItem: wallpaperRef; live: true; visible: false }

    Row {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            width: root.implicitWidth / 2
            height: root.implicitHeight
            color: "transparent"
            Rectangle {
                id: leftLens
                anchors.centerIn: parent
                width: 200
                height: 48
                radius: 24
                color: "transparent"
                Glass {
                    anchors.fill: parent
                    options: Config.island
                    tint: Theme.glassTint
                    radius: 24
                    shadow: false
                    useCompositor: false
                    texture: wallpaperTex
                    textureRect: Qt.rect(leftLens.x / wallpaperRef.width, leftLens.y / wallpaperRef.height,
                                         leftLens.width / wallpaperRef.width, leftLens.height / wallpaperRef.height)
                }
            }
            Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter; text: "Preview (useCompositor: false)"; color: "white"; font.pixelSize: 12 }
        }

        Rectangle {
            width: root.implicitWidth / 2
            height: root.implicitHeight
            color: "transparent"
            Rectangle {
                id: rightLens
                anchors.centerIn: parent
                width: 200
                height: 48
                radius: 24
                color: "transparent"
                Glass {
                    anchors.fill: parent
                    options: Config.island
                    tint: Theme.glassTint
                    radius: 24
                    shadow: false
                    useCompositor: true
                    texture: wallpaperTex
                    textureRect: Qt.rect(rightLens.x / wallpaperRef.width, rightLens.y / wallpaperRef.height,
                                         rightLens.width / wallpaperRef.width, rightLens.height / wallpaperRef.height)
                }
            }
            Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter; text: "Island (useCompositor: true)"; color: "white"; font.pixelSize: 12 }
        }
    }
}
