import QtQuick
import "lib/backdrop.js" as Backdrop
import "lib/material.js" as Material
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "adapters" as Adapters
FloatingWindow {
    id: win
    title: I18n.tr("Tahow Preferences")
    implicitWidth: 820; implicitHeight: 680
    minimumSize: Qt.size(780,520)
    visible: true; color: "transparent"
    onVisibleChanged: if (!visible) Hub.settingsOpen = false
    readonly property bool ryokuSession: !!Host.adapter || ryokuSocket.connected
    Socket {
        id: ryokuSocket
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
        connected: !Host.adapter
        onError: connected = false
    }
    property int page: 0
    readonly property var pages: [
        {title:"Wi-Fi", icon:"wifi", page:7, searchTerms:["Connectivity"]},
        {title:"Bluetooth", icon:"bluetooth", page:8, searchTerms:["Connectivity"]},
        {title:"Notifications", icon:"notifications", page:11,
            searchTerms:["Focus", "Do Not Disturb"],
            keys:["notifications","notifStyle","bannerTimeout","previews","groupByApp"]},
        {title:"Sound", icon:"volume_up", page:12, keys:["notifSound","soundFile"]},
        {title:"General", icon:"tune", page:4, searchTerms:["Language", "System"]},
        {title:"Appearance", icon:"palette", page:0, keys:["iconStyle"], searchTerms:["Icon style"]},
        {title:"Wallpaper", icon:"image", page:24},
        {title:"Glass", icon:"blur_on", page:6},
        {title:"Island", icon:"island", page:1},
        {title:"Spotlight", icon:"search", page:2},
        {title:"Lock Screen", icon:"lock", page:3},
        {title:"Keyboard", icon:"keyboard", page:10, searchTerms:["Input & Shortcuts"]},
        {title:"Mouse", icon:"mouse", page:9},
        {title:"Input panel", icon:"input_panel", page:23},
        {title:"Shortcuts", icon:"bolt", page:5}
    ]
    property string pageSearch: ""
    readonly property var currentPage: pages.find(entry => entry.page === page)
    readonly property var focusKeys: ["dndAllowCritical"]
    readonly property var categorizedKeys: pages.reduce((keys, entry) => keys.concat(entry.keys || []),
        focusKeys.concat(["dnd", "focusSchedule", "focusAllowedApps", "ccLayout"]))
    readonly property var visiblePages: {
        const query = pageSearch.trim().toLowerCase();
        return pages.filter(entry => [entry.title].concat(entry.searchTerms || [])
            .some(term => I18n.tr(term).toLowerCase().includes(query)));
    }
    onPageChanged: {
        Hub.settingsConnectivity = page === 7 ? "wifi" : page === 8 ? "bt" : "";
    }
    Component.onDestruction: {
        Hub.settingsConnectivity = "";
        if (ownsCapture) Host.endCapture();
    }
    readonly property bool inputPage: page === 23
    readonly property string scope: inputPage ? "input" : page === 6 ? glassSettings.scope : (["general", "island", "palette", "lockscreen"][page] || "general")
    readonly property var visualKeys: ["style","appearance","accentSource","customAccent","glassOpacity","glassRim","innerShadow","glassAccentTint","frost","font","motion","fastDuration","mediumDuration","easing"]
    readonly property var islandKeys: visualKeys.concat(["bezel","thickness","ior","dispersion","compactPadding","topMargin","outerGaps","screenCapture","reserveSpace","overlayBar","hoverPeek","hoverDelay","splitActivities","activityClock","use24h","showAmPm","showSeconds","showBattery","showPrivacy","workspaceFlash"])
    readonly property var paletteKeys: visualKeys.concat(["dispersion","palettePosition","columns","matWidth","screenCapture","hiddenApps","pinnedApps"])
    readonly property var lockKeys: ["appearance","accentSource","customAccent","font","motion","fastDuration","mediumDuration","easing","use24h","lockFooterScale","lockRim","lockTint","lockThickness","lockIor","lockDispersion","lockEnergy","lockBezel","pamService"]
    readonly property var keys: page === 0 ? currentPage.keys.concat(visualKeys) : page === 1 ? islandKeys : page === 2 ? paletteKeys : page === 3 ? lockKeys : page === 4 ? ["language"].concat(Object.keys(Config.defaults).filter(k => !["loginFollowWallpaper", "desktopWallpaperPath", "desktopWallpaperMode"].includes(k) && (win.ryokuSession || k !== "reloadCoverFollowWallpaper") && k !== "language" && k !== "settingsAppearance" && visualKeys.indexOf(k) < 0 && islandKeys.indexOf(k) < 0 && paletteKeys.indexOf(k) < 0 && lockKeys.indexOf(k) < 0 && !categorizedKeys.includes(k))) : (currentPage?.keys || [])
    readonly property var choices: ({language:["auto","en-US","pt-BR"],style:["glass","prism","black"],iconStyle:["default","dark","clear","tinted"],appearance:["auto","dark","light"],accentSource:["auto","wallpaper","ryoku","custom","matugen","wal","gtk"],motion:["gentle","balanced","bouncy","reduced"],settingsAppearance:["light","dark"],activityClock:["split","inline","hidden"],units:["metric","imperial"],notifStyle:["banner","island","corner"],previews:["always","never"],locationMode:["auto","manual","ip"]})
    property var bindings: []
    property string shortcutSearch: ""
    readonly property var filteredBindings: bindings.filter(b => !shortcutSearch || (shortcutLabel(b.label) + " " + (b.category || "") + " " + (b.combo || b.chord || "")).toLowerCase().includes(shortcutSearch.toLowerCase().trim()))
    function shortcutLabel(label) {
        const workspace = /^Go to workspace (\d+)$/.exec(label || "");
        return workspace ? I18n.tr("Go to workspace {number}", {number: workspace[1]})
            : I18n.tr(label || "Compositor action");
    }
    function label(key) { return key.replace(/([A-Z])/g, " $1").replace(/^./, c => c.toUpperCase()); }
    function save(key, value) {
        if (typeof value === "number" && !isFinite(value)) return;
        Config.set(scope,key,value);
    }
    Shortcut { sequence: "Escape"; onActivated: Hub.settingsOpen = false }
    FileDialog {
        id: loginWallpaperPicker
        title: I18n.tr("Upload login wallpaper")
        nameFilters: [I18n.tr("Images") + " (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            Config.set("general", "loginFollowWallpaper", false);
            LoginWallpaper.publish(selectedFile.toString());
        }
    }
    ColorDialog { id: picker; selectedColor: Config.value(win.scope,"customAccent"); onAccepted: Config.setValues(win.scope, {customAccent: selectedColor.toString(), accentSource: "custom"}) }
    Process {
        readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
        command: hyprland ? ["hyprctl", "-j", "binds"] : ["ryoku-hub", "keybinds"]
        running: win.page === 5 && (hyprland || win.ryokuSession)
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed)) {
                        win.bindings = parsed.map(bind => {
                            const mods = [[64, "Super"], [8, "Alt"], [4, "Ctrl"], [1, "Shift"],
                                [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]];
                            const keyNames = {space: I18n.tr("Space"), left: "←", right: "→", up: "↑", down: "↓", tab: "Tab", return: "Enter", escape: "Esc"};
                            const key = keyNames[String(bind.key || "").toLowerCase()] || bind.key || String(bind.keycode);
                            const actions = {killactive: "Close window", fullscreen: "Toggle fullscreen", cyclenext: "Switch windows",
                                alterzorder: "Raise window", exec: "Run command"};
                            const action = bind.dispatcher === "workspace" && /^\d+$/.test(bind.arg)
                                ? "Go to workspace " + bind.arg : actions[bind.dispatcher] || "Compositor action";
                            return {label: bind.description || action,
                                category: bind.submap || "", combo: mods.filter(mod => bind.modmask & mod[0])
                                    .map(mod => mod[1]).concat(key).join(" + ")};
                        });
                    } else {
                        win.bindings = (parsed.categories || []).flatMap(category =>
                            (category.binds || []).map(bind => Object.assign({category: category.name}, bind)));
                    }
                } catch (_) { win.bindings = []; }
            }
        }
    }
    SettingsControls.Colors { id: colors }
    readonly property bool settingsDark: colors.darkAppearance
    readonly property color paper: colors.window
    readonly property color ink: colors.windowText
    readonly property color secondary: colors.placeholderText
    readonly property color group: colors.base
    readonly property color accent: colors.highlight
    readonly property var labels: ({dnd:"Do Not Disturb",dndAllowCritical:"Allow critical notifications",notifStyle:"Notification style",bannerTimeout:"Banner duration (seconds)",previews:"Previews",groupByApp:"Group notifications by app",notifSound:"Notification sound",soundFile:"Sound file",reloadCoverFollowWallpaper:"Generate glass reload cover from wallpaper",language:"Language",style:"Material",appearance:"Appearance",accentSource:"Color source",customAccent:"Accent color",glassOpacity:"Glass opacity",glassRim:"Specular rim",innerShadow:"Inner shadow",glassAccentTint:"Tint glass with accent",frost:"Frost",font:"Typeface",motion:"Animation",fastDuration:"Quick transitions (ms)",mediumDuration:"Transitions (ms)",easing:"Transition curve",bezel:"Lens edge",thickness:"Refraction depth",ior:"Refractive index",dispersion:"Chromatic dispersion",palettePosition:"Vertical position",screenCapture:"Refract desktop content",use24h:"24-hour clock",compactPadding:"Compact side padding",topMargin:"Distance from top",outerGaps:"Outer spacing",hoverPeek:"Preview on hover",hoverDelay:"Hover delay (ms)",matWidth:"Application tile width",columns:"Application columns",lockFooterScale:"Login panel size",lockRim:"Password field rim",lockTint:"Password field tint",lockThickness:"Password field depth",lockIor:"Password field refraction",lockDispersion:"Password field dispersion",lockEnergy:"Password field highlight",lockBezel:"Password field bevel",pamService:"PAM service (standalone)",reserveSpace:"Reserve space for the island",overlayBar:"Float over windows"})


    component FormRow: Rectangle {
        id: form
        required property string settingKey
        readonly property var current: Config.value(win.scope, settingKey)
        readonly property var options: win.choices[settingKey] || []
        readonly property string caption: I18n.tr(settingKey === "useSystemFileManager"
            ? "Use the system file manager" : win.labels[settingKey] || win.label(settingKey))
        width: parent.width; height: 45; radius: 7; color: win.group
        Label { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 220; text: form.caption; color: win.ink; font.family: "Inter"; font.pixelSize: 13; elide: Text.ElideRight }
        SettingsControls.Toggle { anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; visible: typeof form.current === "boolean"; checked: form.current === true; Accessible.name: form.caption; onToggled: win.save(form.settingKey,checked) }
        SettingsControls.Choice {
            Accessible.name: form.caption
            itemLabel: value => {
                if (form.settingKey === "language") return I18n.languageLabel(value, win.ryokuSession);
                if (form.settingKey === "iconStyle") return I18n.tr(win.label(value));
                return I18n.tr(value);
            }
            visible: form.options.length > 0
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 170; height: 30; model: form.options; currentIndex: form.options.indexOf(form.current)
            onActivated: win.save(form.settingKey,form.options[currentIndex])
        }
        SettingsControls.Field {
            visible: form.options.length === 0 && typeof form.current !== "boolean"
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 170; height: 30
            text: typeof form.current === "object" ? JSON.stringify(form.current) : String(form.current ?? "")
            Accessible.name: form.caption; horizontalAlignment: Text.AlignRight
            onEditingFinished: { if (typeof form.current === "object") { try { win.save(form.settingKey,JSON.parse(text)); } catch (_) {} } else win.save(form.settingKey,typeof form.current === "number" ? Number(text) : text); }
        }
    }
    property bool materialReady: !Config.general.screenCapture
    property bool ownsCapture: false
    Component.onCompleted: if (!materialReady) { ownsCapture = true; Host.beginCapture(); materialDelay.start(); }
    Binding { target: win.contentItem; property: "opacity"; value: win.materialReady ? 1 : 0 }
    Timer { id: materialDelay; interval: 64; onTriggered: settingsCapture.captureSource = win.screen }
    ScreencopyView {
        id: settingsCapture; width: win.screen ? win.screen.width : 1; height: win.screen ? win.screen.height : 1
        paintCursor: false; live: !win.materialReady
        onHasContentChanged: if (hasContent) { settingsTexture.scheduleUpdate(); materialFinish.start(); }
    }
    ShaderEffectSource { id: settingsTexture; sourceItem: settingsCapture; textureSize: { const s = Backdrop.size(settingsCapture.width, settingsCapture.height); return Qt.size(s.width, s.height); } live: false; visible: false; hideSource: true; mipmap: true }
    function finishMaterial() { materialReady = true; if (ownsCapture) { ownsCapture = false; Host.endCapture(); } }
    Timer { id: materialFinish; interval: 16; onTriggered: win.finishMaterial() }
    Timer { interval: 220; running: win.ownsCapture; onTriggered: win.finishMaterial() }
    readonly property color sidebarTint: Qt.rgba(paper.r * 0.88 + accent.r * 0.12, paper.g * 0.88 + accent.g * 0.12, paper.b * 0.88 + accent.b * 0.12, 1)
    Rectangle { anchors.fill: parent; z: 1; radius: 18; color: "transparent"; border.color: win.settingsDark ? "#505056" : "#e8e8eb" }
    Rectangle {
        id: side; width: 226; height: parent.height
        topLeftRadius: 18; bottomLeftRadius: 18
        color: Theme.alpha(win.sidebarTint, compositor.ready ? 0.2 : 1)
        CompositorGlass {
            id: compositor; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: parent.width + 18; target: "tahow-settings"
            discoverWhileHidden: true
            active: Config.general.screenCapture
            radius: 18
            prism: Config.general.style === "prism"
            bezel: Material.glassBezel(Config.general.bezel)
            thickness: Config.general.thickness * Material.glassRefraction(prism)
            ior: Config.general.ior; dispersion: Config.general.dispersion; frost: Config.general.frost
            innerShadow: Material.glassInnerShadow(Config.general.innerShadow)
            rim: Config.general.glassRim ? Config.general.rimStrength : 0
            onAvailableChanged: if (available) {
                materialDelay.stop(); settingsCapture.captureSource = null;
                win.finishMaterial();
            }
        }
        NativeGlass {
            anchors.fill: parent; visible: settingsCapture.hasContent && !compositor.ready
            src: settingsTexture; topLeftRadius: 18; bottomLeftRadius: 18
            tintColor: win.sidebarTint; tintAmount: 0
            prism: compositor.prism ? 1 : 0
            bezel: compositor.bezel; thickness: compositor.thickness
            ior: compositor.ior; dispersion: compositor.dispersion * Material.glassRefraction(compositor.prism); frost: compositor.frost / 5
            innerShadow: compositor.innerShadow; rim: compositor.rim
            sourceRect: { const p = side.mapToGlobal(0,0); return Qt.rect((p.x - Screen.virtualX)/Math.max(1,Screen.width),(p.y - Screen.virtualY)/Math.max(1,Screen.height),side.width/Math.max(1,Screen.width),side.height/Math.max(1,Screen.height)); }
        }
        Rectangle {
            anchors.fill: parent; topLeftRadius: side.topLeftRadius; bottomLeftRadius: side.bottomLeftRadius
            color: win.sidebarTint; opacity: win.settingsDark ? 0.56 : 0.48
        }
        Text {
            x: 42; y: 20; width: parent.width - x - 12
            text: I18n.tr("Tahow Preferences")
            color: win.ink; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        SettingsControls.Button {
            id: closeButton
            x: 10; y: 12; width: 28; height: 32
            text: I18n.tr("Close")
            padding: 0
            contentItem: Item {}
            background: Item {
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: closeButton.down ? "#d9423b" : closeButton.hovered ? "#ff746d" : "#ff5f57"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 20; height: 20; radius: 10
                    visible: closeButton.visualFocus
                    color: "transparent"; border.width: 2; border.color: win.accent
                }
            }
            onClicked: Hub.settingsOpen = false
        }
        Rectangle { x: 14; y: 54; width: parent.width - 28; height: 32; radius: 8; color: win.group
            Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; text: "search"; size: 16; color: win.secondary }
            TextInput { x: 35; width: parent.width - 44; height: parent.height; verticalAlignment: TextInput.AlignVCenter; font.family: "Inter"; font.pixelSize: 13; color: win.ink; Accessible.name: I18n.tr("Search"); onTextChanged: win.pageSearch = text
                onAccepted: if (win.visiblePages.length) win.page = win.visiblePages[0].page
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: I18n.tr("Search"); color: win.secondary; font: parent.font }
            }
        }
        ScrollView {
            x: 12; y: 96; width: side.width - 24; height: side.height - y - 12
            contentWidth: availableWidth; clip: true
            ScrollBar.vertical: SettingsControls.Bar {}
            Column {
                width: parent.width; spacing: 4
                Repeater {
                    model: win.visiblePages
                    ItemDelegate {
                        id: entry
                        required property var modelData
                        width: parent.width; height: 34
                        text: I18n.tr(modelData.title)
                        highlighted: modelData.page === win.page
                        onClicked: win.page = modelData.page
                        background: Rectangle {
                            radius: 6
                            color: entry.highlighted ? Theme.alpha(win.accent, 0.26) : entry.hovered ? win.group : "transparent"
                            border.width: entry.visualFocus ? 2 : 0
                            border.color: win.accent
                        }
                        contentItem: Row {
                            spacing: 8
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20; radius: 5
                                color: entry.highlighted ? win.accent : win.group
                                Icon {
                                    anchors.centerIn: parent
                                    text: entry.modelData.icon; size: 14
                                    color: entry.highlighted ? (Theme.lum(win.accent) > 0.6 ? "#182233" : "white") : win.ink
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28
                                text: entry.text; font.family: "Inter"; font.pixelSize: 12
                                color: win.ink; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
    Rectangle {
        id: main; x: side.width; width: parent.width - x; height: parent.height
        topRightRadius: 18; bottomRightRadius: 18; color: win.paper
        Text {
            x: 24; y: 22
            text: I18n.tr(win.currentPage?.title || "Appearance")
            color: win.ink; font.family: "Inter"; font.pixelSize: 17; font.weight: Font.DemiBold
        }
        readonly property int contentTop: 62
        Loader {
            x: 24; y: main.contentTop; width: parent.width - 48; height: parent.height - y - 24
            active: win.page === 7 || win.page === 8
            sourceComponent: win.page === 7 ? wifiSettings : bluetoothSettings
        }
        Component { id: wifiSettings; WifiPage { embedded: true } }
        Component { id: bluetoothSettings; BluetoothPage { embedded: true } }
        ScrollView {
            id: settingsScroll
            visible: win.page !== 7 && win.page !== 8
            x: 20; y: main.contentTop; width: parent.width - 40; height: parent.height - y - 14
            clip: true; contentWidth: availableWidth
            Connections {
                target: win
                function onPageChanged() { settingsScroll.contentItem.contentY = 0; }
            }
            ScrollBar.vertical: SettingsControls.Bar {}
            Column { width: parent.width; spacing: 12
                Column {
                    visible: win.page === 3; width: parent.width; spacing: 10
                    Text { text: I18n.tr("Login wallpaper"); color: win.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Row {
                        spacing: 12
                        SettingsControls.Button { text: I18n.tr("Upload login wallpaper"); enabled: !LoginWallpaper.busy; onClicked: loginWallpaperPicker.open() }
                        SettingsControls.Toggle {
                            visible: win.ryokuSession
                            text: I18n.tr("Follow Ryoku wallpaper")
                            checked: Config.s.loginFollowWallpaper
                            onToggled: Config.set("general", "loginFollowWallpaper", checked)
                        }
                    }
                    Text { width: parent.width; wrapMode: Text.WordWrap; color: win.secondary; font.pixelSize: 12; text: I18n.tr("Login wallpaper requires the Tahow login integration. Images are copied outside your home for boot access.") }
                    Text { width: parent.width; wrapMode: Text.WordWrap; color: win.secondary; font.pixelSize: 12; text: I18n.tr(LoginWallpaper.status) }
                }
                Loader {
                    active: win.page === 24
                    visible: active
                    width: parent.width
                    sourceComponent: WallpaperPage { ink: win.ink; secondary: win.secondary; paper: win.group; accent: win.accent }
                }
                GlassSettings {
                    id: glassSettings
                    visible: win.page === 6 || win.inputPage; width: parent.width
                    fixedScope: win.inputPage ? "input" : ""
                    paper: win.paper; ink: win.ink; secondary: win.secondary; group: win.group; accent: win.accent
                }
                Rectangle {
                    visible: win.page < 4 || win.inputPage; width: parent.width; height: 116; radius: 10; color: win.group
                    Text { x: 14; y: 15; text: I18n.tr("Appearance"); font.family: "Inter"; font.pixelSize: 13; color: win.ink }
                    Row { anchors.right: parent.right; anchors.rightMargin: 14; y: 12; spacing: 12
                        Repeater { model: ["auto","light","dark"]
                            Column { id: appearance; required property string modelData; spacing: 5
                                Rectangle { width: 82; height: 66; radius: 9; color: "transparent"; border.width: Config.value(win.scope,"appearance") === appearance.modelData ? 2 : 0; border.color: win.accent
                                    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 5; clip: true
                                        gradient: Gradient { GradientStop { position: 0; color: appearance.modelData === "dark" ? "#17337d" : "#8adbfa" } GradientStop { position: .6; color: "#167dde" } GradientStop { position: 1; color: "#1546b3" } }
                                        Rectangle { x: 9; y: 25; width: 52; height: 30; radius: 4; color: appearance.modelData === "dark" ? "#24262c" : "white"; opacity: .95
                                            Rectangle { width: 16; height: parent.height; radius: 4; color: appearance.modelData === "dark" ? "#3e4150" : "#d9edf7" }
                                            Row { x: 4; y: 4; spacing: 2; Repeater { model:["#ff6057","#ffbe2e","#29c941"]; Rectangle { required property string modelData; width:3;height:3;radius:2;color:modelData } } }
                                        }
                                        Rectangle { visible: appearance.modelData === "auto"; x: parent.width/2; width: parent.width/2; height: parent.height; color:"#131d47"; opacity:.7 }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: win.save("appearance",appearance.modelData); cursorShape: Qt.PointingHandCursor }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr(appearance.modelData[0].toUpperCase()+appearance.modelData.slice(1)); font.family: "Inter"; font.pixelSize:11; color:win.ink }
                            }
                        }
                    }
                }
                Column { visible: win.page < 4 || win.inputPage; width: parent.width; spacing: 8
                    Text { text: I18n.tr("Theme"); color: win.ink; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold; leftPadding: 14 }
                    Rectangle { width:parent.width;height:88;radius:10;color:win.group
                        Text { x:14;y:17;text: I18n.tr("Color");color:win.ink;font.family:"Inter";font.pixelSize:13 }
                        Row { anchors.right:parent.right;anchors.rightMargin:14;y:16;spacing:10
                            Repeater { model:["#008aff","#9a44af","#ef4fa8","#fa3d45","#ff9513","#ffcf1e","#33bd4b","#96969a"]
                                Rectangle { required property string modelData; width:24;height:24;radius:12;color:modelData;border.width: Config.value(win.scope,"accentSource") === "custom" && Config.value(win.scope,"customAccent") === modelData ? 2 : 0;border.color:win.ink
                                    MouseArea { anchors.fill:parent;onClicked: Config.setValues(win.scope, {customAccent: parent.modelData, accentSource: "custom"}) }
                                }
                            }
                            Rectangle { width:24;height:24;radius:12;gradient:Gradient { GradientStop{position:0;color:"#ff568b"} GradientStop{position:.5;color:"#8e5de7"} GradientStop{position:1;color:"#12bde8"} } MouseArea{anchors.fill:parent;onClicked:picker.open()} }
                        }
                        Rectangle { x:14;y:49;width:parent.width-28;height:1;color:win.settingsDark?"#404044":"#e9e9ec" }
                        Text { x:14;y:61;text: I18n.tr("Follow wallpaper colors");color:win.ink;font.family:"Inter";font.pixelSize:12 }
                        SettingsControls.Toggle {
                            anchors.right: parent.right; anchors.rightMargin: 15; y: 56
                            checked: Config.value(win.scope, "accentSource") === "wallpaper"
                            palette.highlight: Theme.materialAccent(Config.effective(win.scope))
                            Accessible.name: I18n.tr("Follow wallpaper colors")
                            onToggled: win.save("accentSource", checked ? "wallpaper" : "custom")
                        }
                    }
                }
                Rectangle {
                    visible: win.page === 12; width: parent.width; height: 54; radius: 8; color: win.group
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        Label { text: I18n.tr("Volume"); color: win.ink }
                        SettingsControls.Range {
                            Layout.fillWidth: true
                            Accessible.name: I18n.tr("Volume")
                            enabled: !!Hub.sink?.audio
                            value: Hub.volume
                            onMoved: Hub.setVolume(value)
                        }
                        SettingsControls.Toggle {
                            text: I18n.tr("Mute")
                            enabled: !!Hub.sink?.audio
                            checked: Hub.muted
                            onToggled: Hub.toggleMute()
                        }
                    }
                }
                Loader {
                    active: win.page === 9 || win.page === 10
                    visible: active; width: parent.width
                    sourceComponent: Adapters.HyprlandInputSettings { keyboard: win.page === 10; ink: win.ink }
                }
                Column { visible: win.page < 5 || win.keys.length > 0; width: parent.width; spacing: 4
                    Item { width:parent.width;height:28
                        Text { text: I18n.tr(win.page===1?"Island & glass":win.page===2?"Palette & motion":win.page===3?"Lockscreen":win.page===11?"Notifications":win.page===12?"Notification sound":"Preferences");color:win.ink;font.family:"Inter";font.pixelSize:14;font.weight:Font.DemiBold;leftPadding:14 }
                        Text { visible:win.scope!=="general";anchors.right:parent.right;anchors.rightMargin:14;text: I18n.tr("Use General");color:win.accent;font.family:"Inter";font.pixelSize:12;MouseArea{anchors.fill:parent;onClicked:Config.inherit(win.scope)} }
                    }
                    Repeater { model:win.keys.filter(k=>["appearance","customAccent","accentSource"].indexOf(k)<0 && glassSettings.glassKeys.indexOf(k)<0);FormRow{required property string modelData;settingKey:modelData} }
                    
                }
                Column {
                    visible: win.page === 11; width: parent.width; spacing: 4
                    Text { text: I18n.tr("Focus"); color: win.ink; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold; leftPadding: 14; bottomPadding: 6 }
                    FocusSettings { width: parent.width }
                    Repeater { model: win.focusKeys; FormRow { required property string modelData; settingKey: modelData } }
                }
                Loader {
                    active: win.page === 2
                    visible: active
                    width: parent.width
                    sourceComponent: SpotlightQuickKeys {}
                }
                Column { visible:win.page===5;width:parent.width;spacing:10
                    SettingsControls.Field { width: parent.width; placeholderText: I18n.tr("Find shortcuts"); onTextChanged: win.shortcutSearch = text }
                    Text { visible: !win.bindings.length; text: I18n.tr("No system shortcuts available."); color: win.secondary }
                    Repeater { model:win.filteredBindings
                        Row { required property var modelData;width:parent.width;height:34
                            Text { width:parent.width*.65;text: win.shortcutLabel(modelData.label);color:win.ink;font.family:"Inter";font.pixelSize:13;elide:Text.ElideRight }
                            Text { text: I18n.tr(modelData.combo||modelData.chord||"Unassigned");color:win.secondary;font.family:"Inter";font.pixelSize:12 }
                        }
                    }
                    Text { width:parent.width;wrapMode:Text.WrapAnywhere;color:win.secondary;font.family:"Inter";font.pixelSize:12;text: I18n.tr("Tahoe IPC\nqs -c shell ipc call tahoe launcher\nqs -c shell ipc call tahoe settings\nqs -c shell ipc call tahoeIsland toggle\nqs -c shell ipc call tahoeIsland center\nqs -c shell ipc call tahoeIsland playPause\nqs -c shell ipc call tahoeIsland next\nqs -c shell ipc call tahoeIsland previous\nqs -c shell ipc call tahoeIsland dnd\nqs -c shell ipc call tahoeIsland timer 300{ryokuCommands}\n\nPalette: arrows · Enter · Tab · Esc\nIsland: click · right-click · middle-click · scroll · 1–4 · Esc", {ryokuCommands: win.ryokuSession ? "\nryoku-shell lock\nryoku-shell suspend" : ""})}
                }
                Text { visible: win.page < 5 || win.inputPage; width:parent.width;wrapMode:Text.WordWrap;text: I18n.tr(win.scope==="general"?"Changes apply across Tahow.":"These preferences override General for this component.");color:win.secondary;font.family:"Inter";font.pixelSize:11;leftPadding:14;bottomPadding:14 }
            }
        }
    }
}
