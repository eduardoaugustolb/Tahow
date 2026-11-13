// Explicit system integration. Run with: sudo bun tools/install-login.ts --user <login>
// Does not restart SDDM or the current session.
import { cpSync, existsSync, lstatSync, mkdirSync, mkdtempSync, renameSync, writeFileSync, chownSync, chmodSync } from 'node:fs';
import { resolve } from 'node:path';
const root = resolve(import.meta.dir, '..');
const index = process.argv.indexOf('--user');
const user = process.argv[index + 1];
if (process.getuid!() !== 0 || index < 0 || !/^[a-z_][a-z0-9_-]*\$?$/i.test(user || '')) throw new Error('Usage: sudo bun tools/install-login.ts --user <login>');
const result = Bun.spawnSync(['id', '-u', user], { stdout: 'pipe' });
if (result.exitCode) throw new Error('Unknown user');
const uid = Number(result.stdout.toString().trim());
if (!Number.isInteger(uid) || uid <= 0) throw new Error('A non-root desktop user is required');
const directory = `/var/lib/tahow/wallpapers/${uid}`;
for (const parent of ['/var/lib/tahow', '/var/lib/tahow/wallpapers']) {
    if (existsSync(parent) && (!lstatSync(parent).isDirectory() || lstatSync(parent).isSymbolicLink() || lstatSync(parent).uid !== 0)) throw new Error(`Unsafe parent: ${parent}`);
    mkdirSync(parent, { recursive: true, mode: 0o755 });
    chmodSync(parent, 0o755);
}
if (existsSync(directory) && (!lstatSync(directory).isDirectory() || lstatSync(directory).isSymbolicLink())) throw new Error('Unsafe wallpaper directory');
mkdirSync(directory, { recursive: true, mode: 0o755 });
chownSync(directory, uid, 0);
chmodSync(directory, 0o755);
const themes = '/usr/share/sddm/themes';
mkdirSync(themes, {recursive: true});
const staged = mkdtempSync(`${themes}/.tahow-`);
cpSync(`${root}/integrations/ryostore/lockscreen/content`, staged, {recursive: true});
chmodSync(staged, 0o755);
writeFileSync(`${staged}/theme.conf`, `[General]\nbackground=file://${directory}/wallpaper.png\nclock24h=true\n`);
const destination = `${themes}/tahoe-shell`;
if (existsSync(destination)) renameSync(destination, `${destination}.backup-${Date.now()}`);
renameSync(staged, destination);
mkdirSync('/etc/sddm.conf.d', {recursive: true});
const selection = '/etc/sddm.conf.d/zz-tahow.conf';
if (existsSync(selection)) cpSync(selection, `${selection}.backup-${Date.now()}`);
writeFileSync(selection, '[Theme]\nCurrent=tahoe-shell\n', {mode: 0o644});
console.log(`Installed Tahow login theme; wallpaper writer UID ${uid}. No services restarted.\nUpload an image in Tahow Settings > Lockscreen, or enable Follow Ryoku wallpaper.\nRollback: remove ${selection} to restore the previous SDDM selection.`);
