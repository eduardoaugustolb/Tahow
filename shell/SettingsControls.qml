import QtQuick
import QtQuick.Controls.Basic as Basic

QtObject {
    component Colors: Palette {
        readonly property bool darkAppearance: Config.general.appearance === "dark"
            || (Config.general.appearance !== "light" && Theme.autoDark)
        window: Theme.mix(darkAppearance ? Qt.color("#242426") : Qt.color("#ffffff"), highlight, 0.09)
        windowText: darkAppearance ? "#f5f5f7" : "#252529"
        buttonText: windowText
        text: windowText
        placeholderText: darkAppearance ? "#a5a5ab" : "#74747b"
        base: Theme.mix(darkAppearance ? Qt.color("#303033") : Qt.color("#f6f6f7"), highlight, 0.06)
        mid: darkAppearance ? "#56565e" : "#c9c9d0"
        highlight: Theme.materialAccent(Config.general, "#0a84ff", Theme.desktopWallAccent)
        highlightedText: Theme.lum(highlight) > 0.6 ? "#182233" : "white"
    }

    component Surface: Rectangle {
        required property Item control
        radius: 7
        color: control.down || control.hovered ? control.tones.mid : control.tones.base
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? control.tones.highlight : Theme.alpha(control.tones.mid, 0.65)
    }

    component Button: Basic.Button {
        id: button
        readonly property Colors tones: Colors {}
        palette.buttonText: tones.windowText
        font.family: "Inter"
        font.pixelSize: 12
        implicitHeight: 34
        leftPadding: 10
        rightPadding: 10
        opacity: enabled ? 1 : 0.5
        background: Surface { control: button }
    }

    component Field: Basic.TextField {
        id: field
        color: tones.text
        placeholderTextColor: tones.placeholderText
        readonly property Colors tones: Colors {}
        palette.highlight: tones.highlight
        palette.highlightedText: tones.highlightedText
        font.family: "Inter"
        font.pixelSize: 12
        implicitHeight: 34
        leftPadding: 10
        rightPadding: 10
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            radius: 7
            color: field.activeFocus ? field.tones.window : field.tones.base
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? field.tones.highlight : field.tones.mid
        }
    }

    component Choice: Basic.ComboBox {
        id: choice
        property var itemLabel: value => String(value)
        readonly property Colors tones: Colors {}
        palette.buttonText: tones.windowText
        palette.text: tones.text
        palette.windowText: tones.windowText
        palette.highlight: tones.highlight
        palette.highlightedText: tones.highlightedText
        font.family: "Inter"
        font.pixelSize: 12
        implicitHeight: 34
        leftPadding: 10
        rightPadding: 28
        displayText: itemLabel(currentText)
        indicator: Icon {
            x: choice.width - width - 7
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            size: 16
            color: choice.tones.placeholderText
        }
        background: Surface { control: choice }
        delegate: Basic.ItemDelegate {
            id: option
            required property int index
            required property var modelData
            width: ListView.view.width
            height: 30
            text: choice.itemLabel(modelData)
            font: choice.font
            palette.text: choice.tones.text
            palette.buttonText: choice.tones.buttonText
            palette.windowText: choice.tones.windowText
            highlighted: choice.highlightedIndex === index
            background: Rectangle {
                radius: 5
                color: option.highlighted ? Theme.alpha(choice.tones.highlight, 0.25)
                    : option.hovered ? choice.tones.base : "transparent"
            }
        }
        popup: Basic.Popup {
            y: choice.height + 4
            width: choice.width
            padding: 4
            implicitHeight: Math.min(contentItem.contentHeight, 240) + topPadding + bottomPadding
            contentItem: ListView {
                clip: true
                model: choice.popup.visible ? choice.delegateModel : null
                currentIndex: choice.highlightedIndex
                Basic.ScrollBar.vertical: Bar {}
            }
            background: Rectangle {
                radius: 8
                color: choice.tones.window
                border.color: choice.tones.mid
            }
        }
    }

    component Toggle: Basic.Switch {
        id: toggle
        readonly property Colors tones: Colors {}
        palette.highlight: tones.highlight
        palette.buttonText: tones.windowText
        palette.windowText: tones.windowText
        font.family: "Inter"
        font.pixelSize: 12
        spacing: 8
        padding: 0
        implicitHeight: 32
        opacity: enabled ? 1 : 0.5
        indicator: Rectangle {
            x: toggle.leftPadding
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 34
            implicitHeight: 20
            radius: 10
            color: toggle.checked ? toggle.palette.highlight : toggle.tones.mid
            border.width: toggle.visualFocus ? 2 : 0
            border.color: toggle.tones.windowText
            Rectangle {
                x: toggle.checked ? 16 : 2
                y: 2
                width: 16
                height: 16
                radius: 8
                color: "white"
            }
        }
        background: Item {}
    }

    component Range: Basic.Slider {
        id: slider
        readonly property Colors tones: Colors {}
        implicitHeight: 28
        leftPadding: 0
        rightPadding: 0
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 5
            radius: 3
            color: slider.tones.mid
            Rectangle {
                anchors.left: parent.left
                width: slider.position * parent.width
                height: parent.height
                radius: parent.radius
                color: slider.tones.highlight
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 16
            height: 16
            radius: 8
            color: slider.pressed ? slider.tones.highlight : slider.tones.windowText
            border.width: slider.visualFocus ? 2 : 1
            border.color: slider.visualFocus ? slider.tones.highlight : slider.tones.window
        }
    }

    component Bar: Basic.ScrollBar {
        id: bar
        readonly property Colors tones: Colors {}
        implicitWidth: 6
        padding: 1
        contentItem: Rectangle {
            implicitWidth: 4
            implicitHeight: 20
            radius: 2
            color: bar.tones.placeholderText
            opacity: bar.active ? 0.8 : 0
        }
    }
}
