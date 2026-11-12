pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/messages.js" as Messages
import "lib/locale.js" as Locale
Singleton {
    id: root
    property string inheritedLanguage: "auto"
    readonly property string lang: Locale.resolve(Config.s.language,Host.adapter ? Host.adapter.language : inheritedLanguage,Qt.locale().name)
    readonly property var locale: Qt.locale(lang.replace("-","_"))
    function tr(key,args) { return Locale.translate(Messages.catalogs,lang,key,args); }
    function languageLabel(code) { return code === "auto" ? tr("Follow Ryoku / system") : code === "pt-BR" ? "Português (Brasil)" : "English (US)"; }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/ryoku/shell.json"
        watchChanges: true; blockLoading: true; printErrors: false; onFileChanged: reload()
        onLoaded: { try { root.inheritedLanguage = JSON.parse(text()).language || "auto"; } catch (_) {} }
    }
}
