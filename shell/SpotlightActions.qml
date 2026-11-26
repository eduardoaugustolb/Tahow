pragma Singleton
import QtQuick
import "lib/catalog.js" as Catalog
import "lib/quick-keys.js" as QuickKeys

QtObject {
    id: root

    readonly property var defaults: ({
        timer: "25m",
        mic: "mic",
        screenshot: "shot",
        focus: I18n.lang === "pt-BR" ? "foco" : "focus"
    })
    readonly property var keys: QuickKeys.resolve(defaults, Config.palette.quickKeys)
    readonly property var entries: [
        action("timer", I18n.tr("Start 25-minute timer"), "timer"),
        action("mic", I18n.tr("Toggle microphone mute"), "mic"),
        action("screenshot", I18n.tr("Screenshot"), "screenshot_region"),
        action("focus", I18n.tr("Toggle Do Not Disturb"), "bedtime")
    ]

    function action(id, name, glyph) {
        const quickKey = keys[id];
        return {
            id: "tahow-action-" + id,
            actionId: id,
            name,
            glyph,
            quickKey,
            comment: quickKey,
            keywords: [quickKey]
        };
    }

    function search(query, exactOnly) {
        const key = QuickKeys.normalize(query);
        const exact = entries.filter(entry => entry.quickKey === key);
        if (exactOnly) return exact;
        const results = Catalog.results(entries, query, "all", [], []);
        return exact.concat(results.filter(entry => entry.quickKey !== key));
    }

    function setKey(id, value) {
        const key = QuickKeys.normalize(value);
        if (!Object.prototype.hasOwnProperty.call(defaults, id) || !QuickKeys.valid(key)
                || entries.some(entry => entry.actionId !== id && entry.quickKey === key))
            return false;
        if (keys[id] === key) return true;
        const overrides = Object.assign({}, Config.palette.quickKeys || {});
        overrides[id] = key;
        if (QuickKeys.resolve(defaults, overrides)[id] !== key) return false;
        Config.set("palette", "quickKeys", overrides);
        return true;
    }
}
