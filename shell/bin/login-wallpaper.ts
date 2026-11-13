import { chmod, lstat, rename, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

export async function publishWallpaper(input: string, directory = `/var/lib/tahow/wallpapers/${process.getuid!()}`) {
    const source = input.startsWith('file:') ? Bun.fileURLToPath(input) : resolve(input);
    if (!/\.(png|jpe?g|webp|bmp)$/i.test(source)) throw new Error('unsupported-image');
    const info = await lstat(source);
    if (!info.isFile() || info.size > 100 * 1024 * 1024) throw new Error('invalid-image');
    // This directory is provisioned once by the installer. No privileged writes
    // occur on upload or on wallpaper publications, and no home path reaches SDDM.
    const target = await lstat(directory);
    if (!target.isDirectory() || target.isSymbolicLink() || target.uid !== process.getuid!()) throw new Error('setup-required');
    const temporary = `${directory}/.${randomUUID()}.png`;
    try {
        const child = Bun.spawn(['magick', '-limit', 'memory', '128MiB', '-limit', 'map', '256MiB', '-limit', 'time', '20', `${source}[0]`, '-auto-orient', '-resize', '7680x4320>', '-strip', `PNG:${temporary}`], { stdout: 'ignore', stderr: 'ignore' });
        if (await child.exited !== 0) throw new Error('invalid-image');
        await chmod(temporary, 0o644);
        await rename(temporary, `${directory}/wallpaper.png`);
    } finally { await unlink(temporary).catch(() => {}); }
}

if (import.meta.main) {
    try { await publishWallpaper(process.argv[2] || ''); }
    catch (error) { console.error(error instanceof Error ? error.message : 'upload-failed'); process.exitCode = 1; }
}
