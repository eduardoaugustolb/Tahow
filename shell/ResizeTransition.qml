import QtQuick

Behavior {
    id: root
    property var options: Config.island
    readonly property bool elastic: options.motion === "bouncy"
    enabled: options.motion !== "reduced"

    NumberAnimation {
        duration: Math.max(1, root.options.motion === "balanced"
            ? Math.round((root.options.fastDuration + root.options.mediumDuration) / 2)
            : root.options.mediumDuration)
        easing.type: root.elastic ? Easing.OutBack : root.options.easing
        easing.overshoot: 1.05
    }
}
