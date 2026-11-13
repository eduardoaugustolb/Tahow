pragma Singleton
import QtQuick
import "messages.js" as Messages
import "locale.js" as Locale
// SDDM uses a plain Qt engine. Session-only preferences are supplied by
// LiveData; importing Quickshell here would prevent the boot theme loading.
QtObject {
    property string selection: "auto"
    property string inheritedLanguage: "auto"
    readonly property string lang: Locale.resolve(selection, inheritedLanguage, Qt.locale().name)
    readonly property var locale: Qt.locale(lang.replace("-", "_"))
    function tr(key, args) { return Locale.translate(Messages.catalogs, lang, key, args); }
}
