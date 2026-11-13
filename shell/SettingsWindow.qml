import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
FloatingWindow {
    id: win
    title: "Tahow Preferences"
    implicitWidth: 900; implicitHeight: 750
    minimumSize: Qt.size(900,750); maximumSize: Qt.size(900,750)
    visible: true; color: "transparent"
    onVisibleChanged: if (!visible) Hub.settingsOpen = false
    property int page: 0
    readonly property var pages: ["General", "Island", "Command Palette", "Lockscreen", "System", "Shortcuts", "Glass"]
    readonly property var pageOrder: [0, 6, 1, 2, 3, 4, 5]
    readonly property string scope: page === 6 ? glassSettings.scope : ["general", "island", "palette", "lockscreen", "general", "general"][page]
    readonly property var visualKeys: ["style","appearance","accentSource","customAccent","glassOpacity","glassRim","glassAccentTint","frost","font","motion","fastDuration","mediumDuration","easing"]
    readonly property var islandKeys: visualKeys.concat(["bezel","thickness","ior","dispersion","compactPadding","topMargin","outerGaps","screenCapture","reserveSpace","overlayBar","hoverPeek","hoverDelay","splitActivities","activityClock","use24h","showAmPm","showSeconds","showBattery","showPrivacy","workspaceFlash"])
    readonly property var paletteKeys: visualKeys.concat(["dispersion","palettePosition","columns","matWidth","screenCapture","hiddenApps","pinnedApps"])
    readonly property var lockKeys: ["appearance","accentSource","customAccent","font","motion","fastDuration","mediumDuration","easing","use24h","lockFooterScale","lockRim","lockTint","lockThickness","lockIor","lockDispersion","lockEnergy","lockBezel","pamService"]
    readonly property var keys: page === 0 ? ["language"].concat(visualKeys) : page === 1 ? islandKeys : page === 2 ? paletteKeys : page === 3 ? lockKeys : page === 4 ? Object.keys(Config.defaults).filter(k => k !== "loginFollowWallpaper" && k !== "language" && k !== "settingsAppearance" && visualKeys.indexOf(k) < 0 && islandKeys.indexOf(k) < 0 && paletteKeys.indexOf(k) < 0 && lockKeys.indexOf(k) < 0) : []
    readonly property var choices: ({language:["auto","en-US","pt-BR"],style:["glass","black"],appearance:["auto","dark","light"],accentSource:["auto","wallpaper","ryoku","custom","matugen","wal","gtk"],motion:["gentle","balanced","bouncy","reduced"],settingsAppearance:["light","dark"],activityClock:["split","inline","hidden"],units:["metric","imperial"],notifStyle:["banner","island","corner"],previews:["always","never"],locationMode:["auto","manual","ip"]})
    property var bindings: []
    property string shortcutSearch: ""
    readonly property var filteredBindings: bindings.filter(b => !shortcutSearch || (b.label + " " + b.category + " " + b.combo).toLowerCase().indexOf(shortcutSearch.toLowerCase()) >= 0)
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
    ColorDialog { id: picker; selectedColor: Config.value(win.scope,"customAccent"); onAccepted: { win.save("customAccent",selectedColor.toString()); win.save("accentSource","custom"); } }
    Process {
        id: keybinds; command: ["ryoku-hub","keybinds"]
        running: win.page === 5
        stdout: StdioCollector { onStreamFinished: { try { const parsed = JSON.parse(text); win.bindings = (parsed.categories || []).reduce((all,c) => all.concat((c.binds || []).map(b => Object.assign({category:c.name},b))),[]); } catch (_) {} } }
    }    readonly property bool settingsDark: Config.general.appearance === "dark" || (Config.general.appearance !== "light" && DesktopTheme.dark)
    readonly property color paper: settingsDark ? "#242426" : "#ffffff"
    readonly property color ink: settingsDark ? "#f5f5f7" : "#252529"
    readonly property color secondary: settingsDark ? "#a5a5ab" : "#74747b"
    readonly property color group: settingsDark ? "#303033" : "#f6f6f7"
    readonly property color accent: Config.value("general","accentSource") === "custom" ? Config.value("general","customAccent") : DesktopTheme.accent
    readonly property var labels: ({reloadCoverFollowWallpaper:"Generate glass reload cover from wallpaper",language:"Language",style:"Material",appearance:"Appearance",accentSource:"Color source",customAccent:"Accent color",glassOpacity:"Glass opacity",glassRim:"Specular rim",glassAccentTint:"Tint glass with accent",frost:"Frost",font:"Typeface",motion:"Animation",fastDuration:"Quick transitions (ms)",mediumDuration:"Transitions (ms)",easing:"Transition curve",bezel:"Lens edge",thickness:"Refraction depth",ior:"Refractive index",dispersion:"Chromatic dispersion",palettePosition:"Vertical position",screenCapture:"Refract desktop content",use24h:"24-hour clock",compactPadding:"Compact side padding",topMargin:"Distance from top",outerGaps:"Outer spacing",hoverPeek:"Preview on hover",hoverDelay:"Hover delay (ms)",matWidth:"Application tile width",columns:"Application columns",lockFooterScale:"Login panel size",lockRim:"Password field rim",lockTint:"Password field tint",lockThickness:"Password field depth",lockIor:"Password field refraction",lockDispersion:"Password field dispersion",lockEnergy:"Password field highlight",lockBezel:"Password field bevel",pamService:"PAM service (standalone)",reserveSpace:"Reserve space for the island",overlayBar:"Float over windows"})


    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
        signal clicked()
        width: 34; height: 20; radius: 10
        color: checked ? win.accent : (win.settingsDark ? "#5a5a60" : "#dedee1")
        Rectangle { x: toggle.checked ? 16 : 2; y: 2; width: 16; height: 16; radius: 8; color: "white"; Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
        MouseArea { anchors.fill: parent; onClicked: toggle.clicked(); cursorShape: Qt.PointingHandCursor }
    }
    component FormRow: Rectangle {
        id: form
        required property string settingKey
        readonly property var current: Config.value(win.scope, settingKey)
        readonly property var options: win.choices[settingKey] || []
        width: parent.width; height: 45; radius: 7; color: win.group
        Label { x: 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 220; text: I18n.tr(win.labels[form.settingKey] || win.label(form.settingKey)); color: win.ink; font.family: "Inter"; font.pixelSize: 13; elide: Text.ElideRight }
        Toggle { anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; visible: typeof form.current === "boolean"; checked: form.current === true; onClicked: win.save(form.settingKey,!checked) }
        ComboBox {
            id: formChoice
            delegate: ItemDelegate { required property var modelData; required property int index; width: formChoice.width; text: form.settingKey === "language" ? I18n.languageLabel(modelData) : I18n.tr(modelData); highlighted: formChoice.highlightedIndex === index }
            visible: form.options.length > 0
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 170; height: 30; model: form.options; currentIndex: form.options.indexOf(form.current)
            onActivated: win.save(form.settingKey,form.options[currentIndex])
            contentItem: Text { text: form.settingKey === "language" ? I18n.languageLabel(parent.displayText) : I18n.tr(parent.displayText); color: win.ink; font.family: "Inter"; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight; rightPadding: 22 }
            background: Rectangle { color: "transparent"; radius: 6 }
        }
        TextField {
            visible: form.options.length === 0 && typeof form.current !== "boolean"
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 170; height: 30
            text: typeof form.current === "object" ? JSON.stringify(form.current) : String(form.current ?? "")
            color: win.ink; font.family: "Inter"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight
            background: Rectangle { radius: 6; color: parent.activeFocus ? (win.settingsDark ? "#45454a" : "#e8e8eb") : "transparent" }
            onEditingFinished: { if (typeof form.current === "object") { try { win.save(form.settingKey,JSON.parse(text)); } catch (_) {} } else win.save(form.settingKey,typeof form.current === "number" ? Number(text) : text); }
        }
    }
    property bool materialReady: !Config.general.screenCapture
    property bool ownsCapture: false
    Component.onCompleted: if (!materialReady) { ownsCapture = true; Host.beginCapture(); materialDelay.start(); }
    Component.onDestruction: if (ownsCapture) Host.endCapture()
    Binding { target: win.contentItem; property: "opacity"; value: win.materialReady ? 1 : 0 }
    Timer { id: materialDelay; interval: 64; onTriggered: settingsCapture.captureSource = win.screen }
    ScreencopyView {
        id: settingsCapture; width: win.screen ? win.screen.width : 1; height: win.screen ? win.screen.height : 1
        paintCursor: false; live: !win.materialReady
        onHasContentChanged: if (hasContent) { settingsTexture.scheduleUpdate(); materialFinish.start(); }
    }
    ShaderEffectSource { id: settingsTexture; sourceItem: settingsCapture; live: false; visible: false; hideSource: true; mipmap: true }
    function finishMaterial() { materialReady = true; if (ownsCapture) { ownsCapture = false; Host.endCapture(); } }
    Timer { id: materialFinish; interval: 16; onTriggered: win.finishMaterial() }
    Timer { interval: 220; running: win.ownsCapture; onTriggered: win.finishMaterial() }
    readonly property color sidebarTint: Qt.rgba(paper.r * 0.88 + accent.r * 0.12, paper.g * 0.88 + accent.g * 0.12, paper.b * 0.88 + accent.b * 0.12, 1)
    Rectangle { anchors.fill: parent; radius: 24; color: "transparent"; border.color: win.settingsDark ? "#505056" : "#e8e8eb" }
    Rectangle {
        id: side; width: 258; height: parent.height; radius: 24
        color: win.sidebarTint
        NativeGlass {
            anchors.fill: parent; visible: settingsCapture.hasContent
            src: settingsTexture; topLeftRadius: 24; bottomLeftRadius: 24
            tintColor: win.sidebarTint; tintAmount: win.settingsDark ? 0.72 : 0.68
            frost: 10; rim: 0.05; bezel: 0; thickness: 0; ior: 1; dispersion: 0
            sourceRect: { const p = side.mapToGlobal(0,0); return Qt.rect((p.x - Screen.virtualX)/Math.max(1,Screen.width),(p.y - Screen.virtualY)/Math.max(1,Screen.height),side.width/Math.max(1,Screen.width),side.height/Math.max(1,Screen.height)); }
        }
        Rectangle { anchors.fill: parent; radius: 24; color: win.sidebarTint; opacity: win.settingsDark ? 0.38 : 0.3 }
        Row { x: 20; y: 20; spacing: 9
            Repeater { model: ["#ff5f57","#ffbd2e","#28c840"]
                Rectangle { required property int index; required property string modelData; width: 15; height: 15; radius: 8; color: modelData
                    MouseArea { anchors.fill: parent; onClicked: { if (parent.index === 0) Hub.settingsOpen = false; else if (parent.index === 1) win.minimized = true; } }
                }
            }
        }
        Rectangle { x: 18; y: 65; width: 222; height: 32; radius: 16; color: win.settingsDark ? "#48555e" : "#cfE4ec"
            Icon { x: 11; anchors.verticalCenter: parent.verticalCenter; text: "search"; size: 16; color: win.secondary }
            TextInput { x: 35; width: parent.width - 44; height: parent.height; verticalAlignment: TextInput.AlignVCenter; font.family: "Inter"; font.pixelSize: 13; color: win.ink; onTextChanged: { win.shortcutSearch = text; if (text) win.page = 5; }
                Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: I18n.tr("Search"); color: win.secondary; font: parent.font }
            }
        }
        Row { x: 24; y: 119; spacing: 10
            Rectangle { width: 36; height: 36; radius: 18; color: win.settingsDark ? "#72777e" : "#aeb8be"; Icon { anchors.centerIn: parent; text: "account_circle"; size: 27; color: "white" } }
            Column { spacing: 3; Text { text: I18n.tr("Tahow"); font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold; color: win.ink } Text { text: I18n.tr("Your desktop, together"); font.family: "Inter"; font.pixelSize: 11; color: win.secondary } }
        }
        Column { x: 12; y: 185; width: 234; spacing: 3
            Repeater {
                model: [{title:"Appearance",icon:"palette",color:"#73747a",page:0},{title:"Glass",icon:"palette",color:"#48a6b8",page:6},{title:"Island",icon:"island",color:"#0b8fff",page:1},{title:"Command Palette",icon:"apps",color:"#a05be8",page:2},{title:"Lockscreen",icon:"lock",color:"#35ba6a",page:3},{title:"System",icon:"tune",color:"#8e8e93",page:4},{title:"Shortcuts",icon:"keyboard",color:"#009de9",page:5}]
                Rectangle { required property var modelData; width: parent.width; height: 35; radius: 8; color: win.page === modelData.page ? win.accent : "transparent"
                    Rectangle { x: 10; y: 6; width: 23; height: 23; radius: 6; color: parent.modelData.color; Icon { anchors.centerIn: parent; text: modelData.icon; size: 17; color: "white" } }
                    Text { x: 43; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(parent.modelData.title); font.family: "Inter"; font.pixelSize: 13; color: win.page === parent.modelData.page ? (win.accent.r*.2126+win.accent.g*.7152+win.accent.b*.0722 > .6 ? "#182233" : "white") : win.ink }
                    MouseArea { anchors.fill: parent; onClicked: win.page = parent.modelData.page; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
        Text { x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 24; text: I18n.tr("Tahow 0.1"); color: win.secondary; font.family: "Inter"; font.pixelSize: 11 }
    }
    Rectangle {
        id: main; x: side.width; width: parent.width - x; height: parent.height; radius: 24; color: win.paper
        Rectangle { width: 24; height: parent.height; color: win.paper }
        Row { x: 22; y: 18; spacing: 14
            Rectangle { width: 72; height: 34; radius: 17; color: win.group
                Icon { x: 9; y: 7; text: "chevron_left"; size: 20; color: win.secondary }
                Icon { x: 43; y: 7; text: "chevron_right"; size: 20; color: win.secondary }
                MouseArea { width: parent.width / 2; height: parent.height; onClicked: win.page = win.pageOrder[Math.max(0,win.pageOrder.indexOf(win.page)-1)] }
                MouseArea { x: parent.width / 2; width: x; height: parent.height; onClicked: win.page = win.pageOrder[Math.min(win.pageOrder.length-1,win.pageOrder.indexOf(win.page)+1)] }
            }
            Text { text: I18n.tr(win.page === 0 ? "Appearance" : win.pages[win.page]); color: win.ink; font.family: "Inter"; font.pixelSize: 17; font.weight: Font.DemiBold; topPadding: 6 }
        }
        ScrollView { x: 20; y: 66; width: parent.width - 40; height: parent.height - 80; clip: true; contentWidth: availableWidth
            Column { width: main.width - 40; spacing: 18
                Column {
                    visible: win.page === 3; width: parent.width; spacing: 10
                    Text { text: I18n.tr("Login wallpaper"); color: win.ink; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Row {
                        spacing: 12
                        Button { text: I18n.tr("Upload login wallpaper"); enabled: !LoginWallpaper.busy; onClicked: loginWallpaperPicker.open() }
                        CheckBox {
                            text: I18n.tr("Follow Ryoku wallpaper")
                            palette.windowText: win.ink
                            palette.highlight: win.accent
                            checked: Config.s.loginFollowWallpaper
                            onClicked: Config.set("general", "loginFollowWallpaper", checked)
                        }
                    }
                    Text { width: parent.width; wrapMode: Text.WordWrap; color: win.secondary; font.pixelSize: 12; text: I18n.tr("Login wallpaper requires the Tahow login integration. Images are copied outside your home for boot access.") }
                    Text { width: parent.width; wrapMode: Text.WordWrap; color: win.secondary; font.pixelSize: 12; text: I18n.tr(LoginWallpaper.status) }
                }
                GlassSettings {
                    id: glassSettings
                    visible: win.page === 6; width: parent.width
                    paper: win.paper; ink: win.ink; secondary: win.secondary; group: win.group; accent: win.accent
                }
                Rectangle {
                    visible: win.page < 4; width: parent.width; height: 116; radius: 10; color: win.group
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
                Column { visible: win.page < 4; width: parent.width; spacing: 8
                    Text { text: I18n.tr("Theme"); color: win.ink; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold; leftPadding: 14 }
                    Rectangle { width:parent.width;height:88;radius:10;color:win.group
                        Text { x:14;y:17;text: I18n.tr("Color");color:win.ink;font.family:"Inter";font.pixelSize:13 }
                        Row { anchors.right:parent.right;anchors.rightMargin:14;y:16;spacing:10
                            Repeater { model:["#008aff","#9a44af","#ef4fa8","#fa3d45","#ff9513","#ffcf1e","#33bd4b","#96969a"]
                                Rectangle { required property string modelData; width:24;height:24;radius:12;color:modelData;border.width:Config.value(win.scope,"customAccent")===modelData?2:0;border.color:win.ink
                                    MouseArea { anchors.fill:parent;onClicked:{win.save("customAccent",parent.modelData);win.save("accentSource","custom");} }
                                }
                            }
                            Rectangle { width:24;height:24;radius:12;gradient:Gradient { GradientStop{position:0;color:"#ff568b"} GradientStop{position:.5;color:"#8e5de7"} GradientStop{position:1;color:"#12bde8"} } MouseArea{anchors.fill:parent;onClicked:picker.open()} }
                        }
                        Rectangle { x:14;y:49;width:parent.width-28;height:1;color:win.settingsDark?"#404044":"#e9e9ec" }
                        Text { x:14;y:61;text: I18n.tr("Follow wallpaper colors");color:win.ink;font.family:"Inter";font.pixelSize:12 }
                        Toggle { anchors.right:parent.right;anchors.rightMargin:15;y:56;checked:Config.value(win.scope,"accentSource")!=="custom";onClicked:win.save("accentSource",checked?"custom":"wallpaper") }
                    }
                }
                Column { visible:win.page<5;width:parent.width;spacing:4
                    Item { width:parent.width;height:28
                        Text { text: I18n.tr(win.page===1?"Island & glass":win.page===2?"Palette & motion":win.page===3?"Lockscreen":"Preferences");color:win.ink;font.family:"Inter";font.pixelSize:14;font.weight:Font.DemiBold;leftPadding:14 }
                        Text { visible:win.scope!=="general";anchors.right:parent.right;anchors.rightMargin:14;text: I18n.tr("Use General");color:win.accent;font.family:"Inter";font.pixelSize:12;MouseArea{anchors.fill:parent;onClicked:Config.inherit(win.scope)} }
                    }
                    Repeater { model:win.keys.filter(k=>["appearance","customAccent","accentSource"].indexOf(k)<0 && glassSettings.glassKeys.indexOf(k)<0);FormRow{required property string modelData;settingKey:modelData} }
                    
                }
                Column { visible:win.page===5;width:parent.width;spacing:10
                    Repeater { model:win.filteredBindings
                        Row { required property var modelData;width:parent.width;height:34
                            Text { width:parent.width*.65;text: I18n.tr(modelData.label);color:win.ink;font.family:"Inter";font.pixelSize:12;elide:Text.ElideRight }
                            Text { text: I18n.tr(modelData.combo||modelData.chord||"Unassigned");color:win.secondary;font.family:"Inter";font.pixelSize:12 }
                        }
                    }
                    Text { width:parent.width;wrapMode:Text.WrapAnywhere;color:win.secondary;font.family:"Inter";font.pixelSize:12;text: I18n.tr("Tahoe IPC\nqs -c shell ipc call tahoe launcher\nqs -c shell ipc call tahoe settings\nqs -c shell ipc call tahoeIsland toggle\nqs -c shell ipc call tahoeIsland center\nqs -c shell ipc call tahoeIsland playPause\nqs -c shell ipc call tahoeIsland next\nqs -c shell ipc call tahoeIsland previous\nqs -c shell ipc call tahoeIsland dnd\nqs -c shell ipc call tahoeIsland timer 300\nryoku-shell lock\nryoku-shell suspend\n\nPalette: arrows · Enter · Tab · Esc\nIsland: click · right-click · middle-click · scroll · 1–4 · Esc")}
                }
                Text { visible: win.page !== 6; width:parent.width;wrapMode:Text.WordWrap;text: I18n.tr(win.scope==="general"?"Changes apply across Tahow.":"These preferences override General for this component.");color:win.secondary;font.family:"Inter";font.pixelSize:11;leftPadding:14;bottomPadding:14 }
            }
        }
    }
}
