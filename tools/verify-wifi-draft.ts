import { mkdtempSync, mkdirSync, symlinkSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = mkdtempSync('/tmp/tahow-wifi-');
try {
    mkdirSync(join(dir, 'run'), { mode: 0o700 });
    symlinkSync(join(import.meta.dir, '../shell'), join(dir, 'tahow'));
    writeFileSync(join(dir, 'nmcli'), `#!/bin/sh
case "$*" in
  "radio wifi") echo enabled ;;
  *'wifi list'*)
    printf x >> "$TAHOW_WIFI_TEST_MARKER"
    echo ':70:WPA2:Mock Network' ;;
esac
`, {mode: 0o700});
    writeFileSync(join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import "./tahow" as Tahow
ShellRoot {
    id: root
    FloatingWindow {
        id: island
        visible: true; implicitWidth: 420; implicitHeight: 400
        Tahow.WifiPage { anchors.fill: parent }
    }
    function find(item) {
        if (item.objectName === "wifi-password" && item.visible) return item;
        for (const child of item.children) { const match = find(child); if (match) return match; }
        return null;
    }
    property var editor: null
    property int stage: 0
    Component.onCompleted: {
        Tahow.Hub.ccPage = "wifi";
        Tahow.Hub.commitTab("", 2);
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            if (root.stage === 0 && Tahow.Hub.wifiNetworks.length > 0) {
                Tahow.Hub.wifiConnect(Tahow.Hub.wifiNetworks[0], "");
                root.stage++;
            } else if (root.stage === 1) {
                root.editor = root.find(island.contentItem);
                if (!root.editor) return;
                root.editor.text = "fictitious-only";
                Tahow.Hub.wifiScan();
                root.stage++;
                done.start();
            }
        }
    }
    Timer {
        id: done; interval: 2800
        onTriggered: {
            if (root.editor && root.editor === root.find(island.contentItem) && root.editor.text === "fictitious-only") {
                Tahow.Hub.ccPage = "";
                if (Tahow.Hub.wifiNeedsPassword === "") console.log("WIFI_DRAFT_OK");
            }
            Qt.quit();
        }
    }
    Timer { interval: 6500; running: true; onTriggered: Qt.quit() }
}
`);
    const marker = join(dir, 'scans');
    const result = Bun.spawnSync(['qs', '-p', join(dir, 'shell.qml')], {
        env: {...process.env, PATH: dir + ':' + process.env.PATH, TAHOW_WIFI_TEST_MARKER: marker,
            XDG_CONFIG_HOME: dir, XDG_RUNTIME_DIR: join(dir, 'run'), QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
        stderr: 'pipe', timeout: 10000,
    });
    const output = result.stdout.toString() + result.stderr.toString();
    if (result.exitCode !== 0 || !output.includes('WIFI_DRAFT_OK') || readFileSync(marker).length < 2) throw new Error(output);
    console.log('Wi-Fi draft survived repeated refresh and cleared on navigation.');
} finally { rmSync(dir, {recursive: true, force: true}); }
