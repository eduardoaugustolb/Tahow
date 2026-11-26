import { execFileSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Isolated preference store: no user settings, input or authentication involved.
const temporary = mkdtempSync(join(tmpdir(), 'tahow-glass-controls-'));
try {
    const settings = join(temporary, 'tahow-shell/settings.json');
    mkdirSync(join(temporary, 'tahow-shell'));
    const wallpaper = join(temporary, 'preview # wallpaper.png');
    writeFileSync(wallpaper, Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAFElEQVQI12NsaGhggAEmBiSAmwMATAQBiIM5jtEAAAAASUVORK5CYII=', 'base64'));
    writeFileSync(settings, JSON.stringify({wallpaperPath: wallpaper, overrides: {island: {dispersion: 0.04}, palette: {columns: 8}}}));
    cpSync(join(import.meta.dir, '../shell'), join(temporary, 'shell'), {recursive: true});
    writeFileSync(join(temporary, 'shell.qml'), readFileSync(join(import.meta.dir, 'verify-glass-settings.qml'), 'utf8').replace('"../shell"', '"./shell"'));
    const output = execFileSync('qs', ['-p', join(temporary, 'shell.qml')], {
        env: {...process.env, XDG_CONFIG_HOME: temporary, XDG_CACHE_HOME: temporary, XDG_RUNTIME_DIR: temporary, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
        encoding: 'utf8', timeout: 10000, stdio: ['ignore', 'pipe', 'pipe']
    });
    if (!output.includes('GLASS_SETTINGS_OK') || output.includes('GLASS_SETTINGS_FAILED')) throw new Error(output);
    const saved = JSON.parse(readFileSync(settings, 'utf8'));
    if (saved.iconStyle !== "tinted" || saved.thickness !== 30 || saved.dispersion !== 0.1 || saved.overrides.island.dispersion !== 0.04
        || saved.overrides.palette.columns !== 8 || saved.overrides.palette.thickness !== undefined
        || saved.overrides.lockscreen.lockThickness !== 48) throw new Error('Preference readback did not match UI changes');
    console.log('Settings OK: accent sources, glass strength, preview, inheritance and persisted readback.');
} finally { rmSync(temporary, {recursive: true, force: true}); }
