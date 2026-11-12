import { describe, expect, test } from 'bun:test';
import { resolve } from 'node:path';
const root = resolve(import.meta.dir, '..');
const source = await Bun.file(`${root}/shell/lib/paths.js`).text();
const paths = Function(source.replace(/^\.pragma library\s*/, '') + '\nreturn { configHome, canonicalDir, legacyDir, canonicalSettingsPath, legacySettingsPath, settingsPath };')();

describe('preferences path policy', () => {
    test('resolves the config home from XDG_CONFIG_HOME when it is set', () => {
        expect(paths.configHome({ HOME: '/home/user', XDG_CONFIG_HOME: '/xdg/config' })).toBe('/xdg/config');
        expect(paths.configHome({ HOME: '/home/user' })).toBe('/home/user/.config');
        expect(paths.configHome({ HOME: '/home/user', XDG_CONFIG_HOME: '' })).toBe('/home/user/.config');
    });

    test('canonical home is tahow-shell and legacy home is tahoe-shell', () => {
        const env = { HOME: '/home/user' };
        expect(paths.canonicalDir(env)).toBe('/home/user/.config/tahow-shell');
        expect(paths.legacyDir(env)).toBe('/home/user/.config/tahoe-shell');
        expect(paths.canonicalSettingsPath(env)).toBe('/home/user/.config/tahow-shell/settings.json');
        expect(paths.legacySettingsPath(env)).toBe('/home/user/.config/tahoe-shell/settings.json');
    });

    test('canonical settings win whenever they exist', () => {
        const env = { HOME: '/home/user' };
        expect(paths.settingsPath(env, true, true)).toBe('/home/user/.config/tahow-shell/settings.json');
        expect(paths.settingsPath(env, true, false)).toBe('/home/user/.config/tahow-shell/settings.json');
    });

    test('legacy settings are adopted only while the canonical file is missing', () => {
        const env = { HOME: '/home/user' };
        expect(paths.settingsPath(env, false, true)).toBe('/home/user/.config/tahoe-shell/settings.json');
        expect(paths.settingsPath(env, false, false)).toBe('/home/user/.config/tahow-shell/settings.json');
    });

    test('a fresh install writes to the canonical path', () => {
        expect(paths.settingsPath({ HOME: '/home/user' }, false, false)).toContain('/tahow-shell/');
    });

    test('generated JS and packaged lockscreen path policy match canonical sources', async () => {
        const run = Bun.spawn(['bun', 'tools/sync-i18n.ts', '--check'], { cwd: root, stdout: 'pipe', stderr: 'pipe' });
        expect(await run.exited).toBe(0);
        expect(await Bun.file(`${root}/integrations/ryostore/lockscreen/content/i18n/paths.js`).text()).toBe(source);
    });
});
