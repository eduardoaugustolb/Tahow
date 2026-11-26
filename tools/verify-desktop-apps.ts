import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { strict as assert } from 'node:assert';

const temporary = mkdtempSync(join(tmpdir(), 'tahow-desktop-apps-'));
try {
    const config = join(temporary, 'shell.qml');
    const home = join(temporary, 'test home');
    const bin = join(temporary, 'bin');
    const argumentsFile = join(temporary, 'kitty-arguments');
    const filesArguments = join(temporary, 'files-arguments');
    mkdirSync(home);
    mkdirSync(bin);
    mkdirSync(join(temporary, 'tahow-shell'));
    writeFileSync(join(temporary, 'tahow-shell', 'settings.json'), JSON.stringify({
        appearance: 'dark', accentSource: 'custom', customAccent: '#38689b'
    }));
    mkdirSync(join(home, 'folder #1'));
    writeFileSync(join(home, 'folder #1', 'test.txt'), '');
    symlinkSync(join(import.meta.dir, '../shell'), join(temporary, 'tahow'));
    writeFileSync(join(bin, 'kitty'), '#!/bin/sh\nprintf "%s\\n" "$@" > "$KITTY_ARGUMENTS_FILE"\n', {mode: 0o755});
    writeFileSync(join(bin, 'xdg-mime'), '#!/bin/sh\nprintf "%s\\n" org.kde.dolphin.desktop\n', {mode: 0o755});
    writeFileSync(join(bin, 'dolphin'), '#!/bin/sh\nprintf "%s\\n" "$XDG_CONFIG_HOME" "$@" > "$FILES_ARGUMENTS_FILE"\n', {mode: 0o755});
    const profile = join(temporary, 'tahow-shell', 'desktop-profile');
    mkdirSync(profile);
    writeFileSync(join(profile, 'kdeglobals'), '[Icons]\nTheme=Tahow-WhiteSur\n');
    writeFileSync(config, `
import QtQuick
import Quickshell
import "./tahow"
import "./tahow/apps" as Apps
ShellRoot {
    Apps.DesktopApps { id: apps }
    Apps.DesktopAppWindow {
        width: 480
        height: 360
        body: Apps.DesktopFiles {
            id: files
            Timer {
                running: true
                interval: 25
                onTriggered: files.navigate(Theme.wallpaperUrl(Quickshell.env("HOME") + "/folder #1"))
            }
            Timer {
                running: true
                interval: 150
                onTriggered: {
                    if (!decodeURIComponent(files.folder.toString()).endsWith("/folder #1"))
                        throw new Error("Folder navigation lost reserved URL characters");
                    if (files.entryCount !== 1)
                        throw new Error("Folder model did not load the test file");
                    if (files.parentFolder.toString() !== files.home.toString())
                        throw new Error("Parent navigation resolved to " + files.parentFolder + ", expected " + files.home);
                    files.navigate(files.parentFolder);
                    if (files.folder.toString() !== files.home.toString())
                        throw new Error("Parent navigation did not reopen the test home");
                    console.log("DESKTOP_FILES_NAVIGATION_OK");
                }
            }
        }
    }
    Timer {
        running: true
        interval: 100
        onTriggered: {
            apps.open("files");
            apps.open("calendar");
            apps.open("files");
            apps.open("terminal");
        }
    }
    Timer {
        running: true
        interval: 350
        onTriggered: {
            apps.closeWindows();
            console.log("DESKTOP_APPS_OK");
            Qt.quit();
        }
    }
}
`);
    const output = execFileSync('qs', ['-p', config], {
        env: {...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, KITTY_ARGUMENTS_FILE: argumentsFile, FILES_ARGUMENTS_FILE: filesArguments,
            XDG_CONFIG_HOME: temporary, XDG_CACHE_HOME: temporary, XDG_RUNTIME_DIR: temporary,
            QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
        encoding: 'utf8', timeout: 10000, stdio: ['ignore', 'pipe', 'pipe']
    });
    assert.match(output, /DESKTOP_APPS_OK/);
    assert.match(output, /DESKTOP_FILES_NAVIGATION_OK/);
    assert.doesNotMatch(output, /TypeError|ReferenceError|Error:|is not a type|Unable to assign/);
    const args = readFileSync(argumentsFile, 'utf8').trimEnd().split('\n');
    assert.equal(args[0], '--config');
    assert.ok(args[1].endsWith('/apps/kitty/dark.conf'));
    assert.match(readFileSync(args[1], 'utf8'), /^background #191c25$/m);
    assert.ok(args.includes('selection_background=#38689b'));
    assert.deepEqual(readFileSync(filesArguments, 'utf8').trimEnd().split('\n'), [profile, '--new-window', home]);
    console.log('Desktop apps verified offscreen with an isolated Dolphin profile and the active Kitty appearance and accent.');
} finally { rmSync(temporary, {recursive: true, force: true}); }
