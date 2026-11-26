import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = mkdtempSync('/tmp/tahow-island-events-');
try {
    const run = join(dir, 'run');
    const network = join(dir, 'network');
    mkdirSync(run, { mode: 0o700 });
    symlinkSync(join(import.meta.dir, '../shell'), join(dir, 'tahow'));
    writeFileSync(network, 'Initial Wi-Fi:802-11-wireless\n');
    writeFileSync(join(dir, 'nmcli'), `#!/bin/sh
case "$*" in
  "radio wifi") echo enabled ;;
  "-t -f NAME,TYPE connection show --active") cat "$TAHOW_TEST_NETWORK" ;;
esac
`, { mode: 0o700 });
    writeFileSync(join(dir, 'shell.qml'), `import QtQuick
import Quickshell
import "./tahow" as Tahow

ShellRoot {
    id: root
    property var observed: []
    FloatingWindow {
        implicitWidth: 440; implicitHeight: 120
        Tahow.Island {
            id: island
            screenName: Quickshell.screens[0]?.name ?? ""
        }
    }
    Connections {
        target: Tahow.Hub
        function onEventSerialChanged() {
            if (Tahow.Hub.event === "device" && Tahow.Hub.eventIcon === "wifi")
                root.observed.push(island.mode + "|" + Tahow.Hub.eventLabel + "|" + Tahow.Hub.eventSub);
        }
    }
    Timer {
        interval: 3000; running: true
        onTriggered: console.log("BASELINE", Tahow.Hub.netName, root.observed.length, island.mode)
    }
    Timer {
        interval: 11500; running: true
        onTriggered: {
            console.log("EVENTS", root.observed.join(", "), Tahow.Hub.expanded, Tahow.Hub.settingsOpen);
            Qt.quit();
        }
    }
}
`);
    const result = Bun.spawn(['qs', '-p', join(dir, 'shell.qml')], {
        env: { ...process.env, PATH: dir + ':' + process.env.PATH, TAHOW_TEST_NETWORK: network,
            XDG_CONFIG_HOME: dir, XDG_RUNTIME_DIR: run, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software' },
        stdout: 'pipe', stderr: 'pipe', timeout: 15000,
    });
    const stdout = new Response(result.stdout).text();
    const stderr = new Response(result.stderr).text();
    await Bun.sleep(3600);
    writeFileSync(network, 'Office\\:Guest:802-11-wireless\n');
    await Bun.sleep(5000);
    writeFileSync(network, '');
    const [code, out, err] = await Promise.all([result.exited, stdout, stderr]);
    if (code !== 0 || !out.includes('BASELINE Initial Wi-Fi 0 idle') ||
        !out.includes('EVENTS device|Office:Guest|Connected, device|Network|Disconnected false false'))
        throw new Error(out + err);
    console.log('The collapsed Island showed both network transitions, with no startup event.');
} finally {
    rmSync(dir, { recursive: true, force: true });
}
