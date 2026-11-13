import {execFileSync} from 'node:child_process';
import {cpSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync} from 'node:fs';

// Requires a live Wayland compositor (PanelWindow has no offscreen backend).
// --wayland enables real capture/GPU; default mode checks capture-disabled fallback.
// Preferences and notifications are fixtures in both modes.
const capture = process.argv.includes('--wayland');
const temporary = mkdtempSync('/tmp/tahow-pill-glass-');
try {
    cpSync('shell', temporary + '/shell', {recursive: true});
    mkdirSync(temporary + '/tahow-shell');
    writeFileSync(temporary + '/tahow-shell/settings.json', JSON.stringify({
        style: 'glass', screenCapture: capture, motion: process.argv.includes('--reduced') ? 'reduced' : 'balanced', topMargin: 160,
        reserveSpace: false, overlayBar: true, notifStyle: 'island', notifSound: false,
        bannerTimeout: 60, weatherEnabled: false, reloadCoverFollowWallpaper: false
    }));
    writeFileSync(temporary + '/shell.qml', readFileSync('tools/verify-pill-glass.qml'));
    const env = {...process.env, XDG_CONFIG_HOME: temporary, TAHOW_CAPTURE_TEST: capture ? '1' : '0'};
    const output = execFileSync('qs', ['-p', temporary + '/shell.qml'], {
        env, encoding: 'utf8', timeout: 16000, stdio: ['ignore', 'pipe', 'pipe']
    });
    if (!output.includes('PILL_GLASS_OK') || output.includes('PILL_GLASS_FAILED')) throw new Error(output);
    console.log(output.split('\n').find(line => line.includes('PILL_GLASS_OK'))?.trim());
} finally {
    rmSync(temporary, {recursive: true, force: true});
}
