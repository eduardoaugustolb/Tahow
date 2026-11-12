import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property color paper
    required property color ink
    required property color secondary
    required property color group
    required property color accent
    spacing: 18
    property int componentIndex: 0
    readonly property var scopes: ["general", "island", "palette", "lockscreen"]
    readonly property var scopeLabels: ["General", "Island", "Command Palette", "Lockscreen"]
    readonly property string scope: scopes[componentIndex]
    readonly property bool lockField: scope === "lockscreen"
    readonly property var options: scope === "general" ? Config.general : Config.effective(scope)
    readonly property bool dark: options.style === "black" || options.appearance === "dark" || (options.appearance !== "light" && Theme.autoDark)
    readonly property color tint: options.style === "black" ? "#000000" : Theme.materialTint(options, dark)
    readonly property var glassKeys: ["style", "glassOpacity", "glassAccentTint", "glassRim", "frost", "screenCapture", "bezel", "thickness", "ior", "dispersion", "lockTint", "lockRim", "lockBezel", "lockThickness", "lockIor", "lockDispersion", "lockEnergy"]
    function save(key, value) { Config.set(scope, key, value); }
    function resetOverrides() { Config.inheritKeys(scope, glassKeys); }
    function optical(key) { return options[lockField ? ({bezel:"lockBezel", thickness:"lockThickness", ior:"lockIor", dispersion:"lockDispersion"})[key] : key]; }
    function valueText(value, digits) { return Number(value).toFixed(digits); }

    Column {
        width: parent.width; spacing: 8
        Label { text: I18n.tr("Apply to"); color: root.secondary; font.pixelSize: 12 }
        Row {
            width: parent.width; spacing: 4
            Repeater {
                model: root.scopeLabels
                Button {
                    id: scopeButton
                    required property int index
                    required property string modelData
                    width: (root.width - 12) / 4; height: 34
                    objectName: "glass-scope-" + root.scopes[index]
                    onClicked: root.componentIndex = index
                    contentItem: Text {
                        text: I18n.tr(scopeButton.modelData); font.pixelSize: 12
                        color: root.componentIndex === scopeButton.index ? (Theme.lum(root.accent) > 0.6 ? "#182233" : "white") : root.ink
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: 8; color: root.componentIndex === scopeButton.index ? root.accent : root.group
                        border.width: scopeButton.activeFocus ? 2 : 0; border.color: root.ink
                    }
                }
            }
        }
    }
    Rectangle {
        width: parent.width; height: 128; radius: 12; clip: true; color: root.group
        Item {
            id: reference
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: root.dark ? "#132b42" : "#b6ddec" }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    x: index * reference.width / 12; y: 0
                    width: reference.width / 24; height: reference.height
                    color: index % 3 === 0 ? root.accent : (root.dark ? "#e3e8ec" : "#17374f")
                    opacity: 0.65
                }
            }
        }
        ShaderEffectSource { id: texture; sourceItem: reference; live: true; hideSource: false; visible: false; mipmap: true }
        Rectangle {
            id: lens
            x: (parent.width - width) / 2; y: 24; width: parent.width * 0.68; height: 80; radius: 22
            color: root.tint
            NativeGlass {
                anchors.fill: parent; visible: root.options.style !== "black"
                src: texture
                sourceRect: Qt.rect(lens.x / reference.width, lens.y / reference.height, lens.width / reference.width, lens.height / reference.height)
                topLeftRadius: 22; topRightRadius: 22; bottomLeftRadius: 22; bottomRightRadius: 22
                tintColor: root.tint
                tintAmount: root.lockField ? root.options.lockTint : root.options.glassOpacity
                bezel: root.optical("bezel"); thickness: root.optical("thickness")
                ior: root.optical("ior"); dispersion: root.optical("dispersion")
                frost: root.lockField ? 0.55 : root.options.frost / 5
                rim: root.lockField ? root.options.lockRim : root.options.glassRim ? 0.25 : 0
                energy: root.lockField ? root.options.lockEnergy : 0
            }
            Rectangle { anchors.fill: parent; radius: parent.radius; color: root.tint; opacity: root.lockField ? root.options.lockTint : root.options.glassOpacity }
            Label { anchors.centerIn: parent; text: I18n.tr("Preview"); color: root.dark ? "white" : "#17171b"; font.pixelSize: 16; font.weight: Font.DemiBold }
        }
    }
    Row {
        width: parent.width; height: 22
        Label { width: parent.width - reset.width; text: I18n.tr(root.scope === "general" ? "General glass settings" : "Component glass overrides"); color: root.ink; font.weight: Font.DemiBold; font.pixelSize: 14 }
        Button {
            id: reset; visible: root.scope !== "general"; width: visible ? implicitWidth : 0; height: 24
            objectName: "glass-use-general"
            text: I18n.tr("Use General"); onClicked: root.resetOverrides()
            contentItem: Text { text: reset.text; color: root.accent; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: "transparent"; radius: 5; border.width: reset.activeFocus ? 1 : 0; border.color: root.accent }
        }
    }
    Row {
        width: parent.width; height: 40
        Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 170; text: I18n.tr("Glass material"); color: root.ink; font.pixelSize: 13 }
        ComboBox {
            id: material; width: 170; height: 34; model: ["glass", "black"]
            currentIndex: root.options.style === "black" ? 1 : 0
            displayText: I18n.tr(currentIndex === 0 ? "glass" : "black")
            delegate: ItemDelegate { required property string modelData; width: material.width; text: I18n.tr(modelData) }
            onActivated: index => root.save("style", model[index])
        }
    }
    component ToggleRow: Row {
        id: toggleRow
        required property string settingKey
        required property string label
        width: root.width; height: 40
        Label { width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(toggleRow.label); color: root.ink; font.pixelSize: 13 }
        Switch {
            id: control
            width: 60; height: 36; anchors.verticalCenter: parent.verticalCenter
            checked: root.options[toggleRow.settingKey] === true
            Accessible.name: I18n.tr(toggleRow.label)
            onToggled: root.save(toggleRow.settingKey, checked)
            indicator: Rectangle {
                x: control.width - width; y: (control.height - height) / 2
                width: 34; height: 20; radius: 10
                color: control.checked ? root.accent : root.group
                border.width: control.activeFocus ? 2 : 1; border.color: control.activeFocus ? root.ink : root.secondary
                Rectangle { x: control.checked ? 16 : 2; y: 2; width: 16; height: 16; radius: 8; color: "white" }
            }
            background: Item {}
        }
    }
    component RangeRow: Column {
        id: row
        required property string settingKey
        required property string label
        required property real minimum
        required property real maximum
        property real step: 0.01
        property int digits: 2
        width: root.width; spacing: 4
        Row {
            width: parent.width; height: 25
            Label { width: parent.width - 74; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(row.label); color: root.ink; font.pixelSize: 13 }
            TextField {
                id: numeric
                objectName: "glass-value-" + row.settingKey
                width: 74; height: 28; color: root.ink; font.pixelSize: 12; horizontalAlignment: Text.AlignRight
                text: root.valueText(root.options[row.settingKey], row.digits)
                validator: DoubleValidator { bottom: row.minimum; top: row.maximum; decimals: row.digits; locale: "en_US" }
                Accessible.name: I18n.tr(row.label)
                onEditingFinished: {
                    const number = Number(text);
                    if (acceptableInput && Number.isFinite(number)) root.save(row.settingKey, Math.max(row.minimum, Math.min(row.maximum, number)));
                    text = Qt.binding(() => root.valueText(root.options[row.settingKey], row.digits));
                }
                background: Rectangle { radius: 6; color: root.group; border.width: numeric.activeFocus ? 1 : 0; border.color: root.accent }
            }
        }
        Slider {
            id: slider; width: parent.width; height: 24
            objectName: "glass-slider-" + row.settingKey
            from: row.minimum; to: row.maximum; stepSize: row.step
            value: root.options[row.settingKey]
            Accessible.name: I18n.tr(row.label)
            onMoved: root.save(row.settingKey, value)
            background: Rectangle {
                x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth; height: 4; radius: 2; color: root.group
                Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: root.accent }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 16; height: 16; radius: 8; color: root.ink
                border.width: slider.activeFocus ? 2 : 0; border.color: root.accent
            }
        }
    }
    RangeRow { settingKey: root.lockField ? "lockTint" : "glassOpacity"; label: root.lockField ? "Password field tint" : "Glass opacity"; minimum: root.lockField ? 0 : 0.15; maximum: 1; digits: 3; step: 0.005 }
    RangeRow { settingKey: root.lockField ? "lockDispersion" : "dispersion"; label: "RGB dispersion"; minimum: 0; maximum: 0.2; step: 0.005; digits: 3 }
    Label { text: I18n.tr("Transparency and tint"); color: root.secondary; font.pixelSize: 12 }
    ToggleRow { settingKey: "glassAccentTint"; label: "Tint glass with accent" }
    ToggleRow { visible: !root.lockField; settingKey: "glassRim"; label: "Specular rim" }
    RangeRow { visible: !root.lockField; settingKey: "frost"; label: "Frost"; minimum: 0; maximum: 30; step: 0.5; digits: 1 }
    Label { text: I18n.tr("Optical refraction"); color: root.secondary; font.pixelSize: 12 }
    ToggleRow { visible: !root.lockField; settingKey: "screenCapture"; label: "Refract desktop content" }
    RangeRow { settingKey: root.lockField ? "lockBezel" : "bezel"; label: "Lens edge"; minimum: 0; maximum: 40; step: 0.5; digits: 1 }
    RangeRow { settingKey: root.lockField ? "lockThickness" : "thickness"; label: "Refraction depth"; minimum: 0; maximum: 60; step: 0.5; digits: 1 }
    RangeRow { settingKey: root.lockField ? "lockIor" : "ior"; label: "Refractive index"; minimum: 1; maximum: 2.5; step: 0.01; digits: 2 }
    RangeRow { visible: root.lockField; settingKey: "lockRim"; label: "Password field rim"; minimum: 0; maximum: 1; step: 0.01; digits: 2 }
    RangeRow { visible: root.lockField; settingKey: "lockEnergy"; label: "Password field highlight"; minimum: 0; maximum: 1; step: 0.01; digits: 2 }
    Label {
        width: parent.width; wrapMode: Text.WordWrap; color: root.secondary; font.pixelSize: 12
        text: I18n.tr("Glass controls apply immediately.") + " " + I18n.tr(root.lockField ? "The lockscreen keeps separate field optics." : "The collapsed island uses simulated glass. Refraction appears when expanded.") + (!root.lockField && !root.options.screenCapture ? " " + I18n.tr("Refraction requires desktop capture.") : "")
    }
}
