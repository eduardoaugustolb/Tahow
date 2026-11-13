import { afterAll, expect, test } from 'bun:test';
import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const quickshell = Bun.which('quickshell');
const integration = quickshell ? test : test.skip;
const temporary = mkdtempSync(join(tmpdir(), 'tahow-preferences-'));
afterAll(() => rmSync(temporary, {recursive: true, force: true}));

function fixture(canonical?: string, legacy?: string) {
    const root = mkdtempSync(join(temporary, 'case-'));
    cpSync(new URL('../shell/Config.qml', import.meta.url), join(root, 'Config.qml'));
    mkdirSync(join(root, 'lib'));
    cpSync(new URL('../shell/lib/paths.js', import.meta.url), join(root, 'lib/paths.js'));
    writeFileSync(join(root, 'qmldir'), 'singleton Config 1.0 Config.qml\n');
    const path = join(root, 'config/tahow-shell/settings.json');
    for (const [directory, content] of [['tahow-shell', canonical], ['tahoe-shell', legacy]]) {
        if (content === undefined) continue;
        mkdirSync(join(root, 'config', directory!), {recursive: true});
        writeFileSync(join(root, 'config', directory!, 'settings.json'), content!);
    }
    return {root, path};
}

function run(root: string, action = '', extra = '') {
    writeFileSync(join(root, 'shell.qml'), `
import QtQuick
import Quickshell
import Quickshell.Io
import "." as Store
ShellRoot {
    id: harness
    function report() {
        console.log("PREFERENCE_STATE:" + JSON.stringify({
            initialized: Store.Config.initialized,
            error: Store.Config.persistenceError,
            general: { topMargin: Store.Config.s.topMargin, use24h: Store.Config.s.use24h },
            overrides: Store.Config.s.overrides
        }));
    }
    Timer {
        interval: 30; running: true
        onTriggered: {
            try { ${action} }
            catch (error) { console.error("PREFERENCE_FAILURE:" + error.message); Qt.quit(); }
        }
    }
    ${extra || 'Timer { interval: 150; running: true; onTriggered: { harness.report(); Qt.quit(); } }'}
    Timer { interval: 3000; running: true; onTriggered: { console.error("PREFERENCE_FAILURE:timeout"); Qt.quit(); } }
}
`);
    const output = execFileSync(quickshell!, ['-p', join(root, 'shell.qml')], {
        env: {...process.env, XDG_CONFIG_HOME: join(root, 'config'), QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
        encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'pipe']
    });
    expect(output).not.toContain('PREFERENCE_FAILURE:');
    const state = output.match(/PREFERENCE_STATE:([^\n]+)/)?.[1];
    expect(state).toBeDefined();
    return JSON.parse(state!);
}

integration('startup always keeps canonical preferences over legacy without rewriting either file', () => {
    const canonical = JSON.stringify({topMargin: 11, use24h: true, overrides: {palette: {columns: 9}}});
    const old = JSON.stringify({topMargin: 99, overrides: {island: {style: 'black'}}});
    const {root, path} = fixture(canonical, old);
    for (let restart = 0; restart < 3; restart++) {
        const state = run(root);
        expect(state.initialized).toBe(true);
        expect(state.general.topMargin).toBe(11);
        expect(state.overrides).toEqual({palette: {columns: 9}});
        expect(readFileSync(path, 'utf8')).toBe(canonical);
        expect(readFileSync(join(root, 'config/tahoe-shell/settings.json'), 'utf8')).toBe(old);
    }
});

integration('edits are persisted even when the shell quits immediately, and survive restart', () => {
    const {root, path} = fixture(JSON.stringify({topMargin: 11, overrides: {palette: {columns: 9}}}), '{"topMargin":99}');
    run(root, `
        Store.Config.set("island", "topMargin", 23);
        Store.Config.set("general", "use24h", true);
        harness.report(); Qt.quit();
    `);
    expect(JSON.parse(readFileSync(path, 'utf8')).overrides).toEqual({island: {topMargin: 23}, palette: {columns: 9}});
    const restarted = run(root);
    expect(restarted.general).toEqual({topMargin: 11, use24h: true});
    expect(restarted.overrides.island.topMargin).toBe(23);
});

integration('legacy migrates once, preserving scopes; future legacy changes cannot replace it', () => {
    const {root, path} = fixture(undefined, JSON.stringify({topMargin: 19, dispersion: 0.13, overrides: {lockscreen: {lockTint: 0.12}}}));
    expect(run(root).general.topMargin).toBe(19);
    const migrated = JSON.parse(readFileSync(path, 'utf8'));
    expect(migrated.overrides.lockscreen.lockTint).toBe(0.12);
    expect(migrated.dispersion).toBe(0.13);
    expect(migrated.bezel).toBe(6);
    writeFileSync(join(root, 'config/tahoe-shell/settings.json'), '{"topMargin":98}');
    expect(run(root).general.topMargin).toBe(19);
});

integration('fresh install creates its preferences directory and persists defaults', () => {
    const {root, path} = fixture();
    expect(run(root).initialized).toBe(true);
    expect(JSON.parse(readFileSync(path, 'utf8')).topMargin).toBe(6);
});

integration('malformed canonical preferences are preserved rather than replaced by defaults or legacy', () => {
    const broken = '{"topMargin":';
    const {root, path} = fixture(broken, '{"topMargin":99}');
    const state = run(root, 'Store.Config.set("island", "topMargin", 23);');
    expect(state.initialized).toBe(false);
    expect(state.error).toContain('Cannot parse preferences');
    expect(readFileSync(path, 'utf8')).toBe(broken);
});

integration('rapid edits survive self-watch events and retain independent component overrides', () => {
    const {root, path} = fixture('{"topMargin":11,"overrides":{"palette":{"columns":9}}}');
    run(root, 'Store.Config.s.use24h = true;', `
        property int step: 0
        Timer {
            interval: 3; running: true; repeat: true
            onTriggered: {
                Store.Config.set("island", "topMargin", harness.step++);
                if (harness.step === 80) { stop(); settle.start(); }
            }
        }
        Timer {
            id: settle; interval: 180
            onTriggered: {
                if (Store.Config.island.topMargin !== 79) console.error("PREFERENCE_FAILURE:stale self reload");
                harness.report(); Qt.quit();
            }
        }
    `);
    const saved = JSON.parse(readFileSync(path, 'utf8'));
    expect(saved.use24h).toBe(true);
    expect(saved.overrides).toEqual({island: {topMargin: 79}, palette: {columns: 9}});
    expect(run(root).overrides).toEqual(saved.overrides);
});

integration('external edits reload and subsequent saves retain them', () => {
    const {root, path} = fixture('{"topMargin":11}');
    const state = run(root, `
        Store.Config.set("general", "use24h", true);
        external.setText(JSON.stringify({topMargin: 31, overrides: {palette: {columns: 12}}}));
        settle.start();
    `, `
        FileView { id: external; path: Store.Config.dir + "/settings.json"; blockWrites: true }
        Timer { id: settle; interval: 180; onTriggered: {
            if (Store.Config.s.topMargin !== 31) console.error("PREFERENCE_FAILURE:external edit did not reload");
            Store.Config.set("island", "topMargin", 24);
            harness.report(); Qt.quit();
        } }
    `);
    expect(state.general.topMargin).toBe(31);
    expect(JSON.parse(readFileSync(path, 'utf8')).overrides).toEqual({palette: {columns: 12}, island: {topMargin: 24}});
});

integration('a canonical path that cannot be read is not replaced with legacy settings', () => {
    const {root, path} = fixture(undefined, '{"topMargin":99}');
    mkdirSync(path, {recursive: true});
    const state = run(root);
    expect(state.initialized).toBe(false);
    expect(state.error).toMatch(/Cannot (read|parse) preferences/);
});

integration('a failed save reports the error instead of silently claiming persistence', () => {
    const {root} = fixture();
    mkdirSync(join(root, 'config'), {recursive: true});
    writeFileSync(join(root, 'config/tahow-shell'), 'blocked');
    const state = run(root, 'Store.Config.set("general", "use24h", true);');
    expect(state.error).toContain('Cannot save preferences');
});
