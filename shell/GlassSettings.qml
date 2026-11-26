import QtQuick
import "lib/material.js" as Material
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
    property string fixedScope: ""
    readonly property var scopes: ["general", "island", "palette", "lockscreen", "input"]
    readonly property var scopeLabels: ["General", "Island", "Spotlight", "Lockscreen", "Input panel"]
    readonly property string scope: fixedScope || scopes[componentIndex]
    readonly property bool lockField: scope === "lockscreen"
    readonly property var options: scope === "general" ? Config.general : Config.effective(scope)
    readonly property bool prismatic: options.style === "prism"
    readonly property bool dark: options.style === "black" || options.appearance === "dark" || (options.appearance !== "light" && Theme.autoDark)
    readonly property color tint: options.style === "black" ? "#000000" : Theme.materialTint(options, dark)
    readonly property bool opticalPreview: options.style !== "black" && (lockField || options.screenCapture)
    readonly property var glassKeys: ["style", "glassOpacity", "glassAccentTint", "glassRim", "rimStrength", "innerShadow", "frost", "screenCapture", "bezel", "thickness", "ior", "dispersion", "lockTint", "lockRim", "lockBezel", "lockThickness", "lockIor", "lockDispersion", "lockEnergy"]
    function save(key, value) { Config.set(scope, key, value); }
    function resetOverrides() {
        if (fixedScope) Config.inherit(scope);
        else Config.inheritKeys(scope, glassKeys);
    }
    function optical(key) { return options[lockField ? ({bezel:"lockBezel", thickness:"lockThickness", ior:"lockIor", dispersion:"lockDispersion"})[key] : key]; }
    readonly property real strength: Math.round(optical("thickness") / 60 * 100)
    function setStrength(percent) {
        const amount = percent / 100;
        const optics = {bezel: 36 * amount, thickness: 60 * amount, ior: 1 + 1.1 * amount, dispersion: 0.2 * amount};
        if (lockField) {
            Config.setValues(scope, {lockBezel: optics.bezel, lockThickness: optics.thickness,
                lockIor: optics.ior, lockDispersion: optics.dispersion});
        } else {
            Config.setValues(scope, Object.assign(optics, {
                frost: 16 - 10 * amount, rimStrength: 0.4 + 0.5 * amount
            }));
        }
    }

    Column {
        visible: root.fixedScope === ""
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
                    width: (root.width - 4 * (root.scopes.length - 1)) / root.scopes.length; height: 34
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
            Image {
                anchors.fill: parent
                objectName: "glass-preview-wallpaper"
                source: Theme.wallpaper ? "file://" + encodeURI(Theme.wallpaper).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        ShaderEffectSource { id: texture; sourceItem: reference; live: true; hideSource: false; visible: false; mipmap: true }
        Rectangle {
            id: lens
            anchors.centerIn: parent; width: Math.min(parent.width - 24, 180)
            height: root.scope === "palette" ? 80 : 38
            radius: root.scope === "palette" ? 22 : height / 2
            color: root.options.style === "black" ? "black" : "transparent"
            Glass {
                anchors.fill: parent
                visible: !root.lockField
                options: root.options
                tint: root.tint
                radius: lens.radius
                shadow: false
                useCompositor: false
                texture: root.opticalPreview ? texture : null
                textureRect: Qt.rect(lens.x / reference.width, lens.y / reference.height, lens.width / reference.width, lens.height / reference.height)
            }
            NativeGlass {
                objectName: "glass-preview-lock-optics"
                anchors.fill: parent; visible: root.lockField && root.opticalPreview
                src: texture
                sourceRect: Qt.rect(lens.x / reference.width, lens.y / reference.height, lens.width / reference.width, lens.height / reference.height)
                topLeftRadius: 22; topRightRadius: 22; bottomLeftRadius: 22; bottomRightRadius: 22
                tintColor: root.tint
                tintAmount: root.options.lockTint
                bezel: Material.glassBezel(root.optical("bezel")) * (root.prismatic ? 1.5 : 1)
                thickness: root.optical("thickness") * (root.prismatic ? 2 : 1) * Material.glassRefraction(root.prismatic)
                ior: root.optical("ior")
                dispersion: root.prismatic ? Math.max(0.16, root.optical("dispersion") * 2) : root.optical("dispersion")
                prism: root.prismatic ? 1 : 0
                frost: 1.5
                innerShadow: Material.glassInnerShadow(1)
                rim: root.options.lockRim
                energy: root.options.lockEnergy
            }
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
        SettingsControls.Choice {
            id: material; width: 170; height: 34; model: ["glass", "prism", "black"]
            currentIndex: Math.max(0, model.indexOf(root.options.style))
            itemLabel: value => I18n.tr(value)
            Accessible.name: I18n.tr("Glass material")
            onActivated: index => root.save("style", model[index])
        }
    }
    component ToggleRow: Row {
        id: toggleRow
        required property string settingKey
        required property string label
        width: root.width; height: 40
        Label { width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(toggleRow.label); color: root.ink; font.pixelSize: 13 }
        SettingsControls.Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: root.options[toggleRow.settingKey] === true
            Accessible.name: I18n.tr(toggleRow.label)
            onToggled: root.save(toggleRow.settingKey, checked)
        }
    }
    Column {
        width: parent.width; spacing: 6
        Label {
            text: I18n.tr("Liquid Glass strength") + " · " + strengthSlider.value + "%"
            color: root.ink; font.pixelSize: 13
        }
        SettingsControls.Range {
            id: strengthSlider
            objectName: "glass-slider-strength"
            width: parent.width
            from: 0; to: 100; stepSize: 1
            value: root.strength
            enabled: root.options.style !== "black"
            Accessible.name: I18n.tr("Liquid Glass strength")
            onMoved: root.setStrength(value)

        }
    }
    ToggleRow { visible: !root.lockField; settingKey: "screenCapture"; label: "Refract desktop content" }
    Label {
        width: parent.width; wrapMode: Text.WordWrap; color: root.secondary; font.pixelSize: 12
        text: I18n.tr("Glass controls apply immediately.") + " " + I18n.tr(root.lockField ? "The lockscreen keeps separate field optics." : "The collapsed island uses simulated glass. Refraction appears when expanded.") + (!root.lockField && !root.options.screenCapture ? " " + I18n.tr("Refraction requires desktop capture.") : "")
    }
}
