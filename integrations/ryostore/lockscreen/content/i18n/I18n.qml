pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "messages.js" as Messages
import "locale.js" as Locale
import "paths.js" as Paths
QtObject {
    id: root
    property string selection: "auto"
    property string inheritedLanguage: "auto"
    property bool canonicalReady: false
    property bool legacyReady: false
    readonly property string env: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config"))
    readonly property string lang: Locale.resolve(selection,inheritedLanguage,Qt.locale().name)
    readonly property var locale: Qt.locale(lang.replace("-","_"))
    function tr(key,args) { return Locale.translate(Messages.catalogs,lang,key,args); }
    readonly property var paths: ({
        HOME: Quickshell.env("HOME"),
        XDG_CONFIG_HOME: Quickshell.env("XDG_CONFIG_HOME"),
    })
    // The canonical ~/.config/tahow-shell/settings.json always wins. The
    // legacy ~/.config/tahoe-shell/settings.json is only read when the
    // canonical file does not exist yet.
    readonly property string ownPath: Paths.settingsPath(root.paths, root.canonicalReady, root.legacyReady)
    property FileView own: FileView {
        path: root.ownPath
        watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: reload()
        onLoaded: { root.canonicalReady = root.ownPath === Paths.canonicalSettingsPath(root.paths); try { root.selection = JSON.parse(text()).language || "auto"; } catch (_) {} }
        onLoadFailed: { root.canonicalReady = false; root.legacyReady = root.ownPath === Paths.legacySettingsPath(root.paths); }
    }
    property FileView inherited: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ryoku/shell.json"
        watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: reload()
        onLoaded: { try { root.inheritedLanguage = JSON.parse(text()).language || "auto"; } catch (_) {} }
    }
}
