import { execFileSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Isolated preference store: no user settings, input or authentication involved.
const temporary = mkdtempSync(join(tmpdir(), 'tahow-glass-controls-'));
try {
    const settings = join(temporary, 'tahow-shell/settings.json');
    mkdirSync(join(temporary, 'tahow-shell'));
    writeFileSync(settings, JSON.stringify({overrides: {island: {dispersion: 0.04}, palette: {columns: 8}}}));
    cpSync(join(import.meta.dir, '../shell'), join(temporary, 'shell'), {recursive: true});
    writeFileSync(join(temporary, 'shell.qml'), readFileSync(join(import.meta.dir, 'verify-glass-settings.qml'), 'utf8').replace('"../shell"', '"./shell"'));
    const output = execFileSync('qs', ['-p', join(temporary, 'shell.qml')], {
        env: {...process.env, XDG_CONFIG_HOME: temporary, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
        encoding: 'utf8', timeout: 10000, stdio: ['ignore', 'pipe', 'pipe']
    });
    if (!output.includes('GLASS_SETTINGS_OK') || output.includes('GLASS_SETTINGS_FAILED')) throw new Error(output);
    const saved = JSON.parse(readFileSync(settings, 'utf8'));
    if (saved.dispersion !== 0.11 || saved.overrides.palette.columns !== 8 || saved.overrides.palette.dispersion !== undefined
        || saved.overrides.lockscreen.lockDispersion !== 0.17) throw new Error('Preference readback did not match UI changes');
    console.log('Glass settings OK: slider, exact input, component inheritance, partial reset and persisted readback.');
} finally { rmSync(temporary, {recursive: true, force: true}); }
