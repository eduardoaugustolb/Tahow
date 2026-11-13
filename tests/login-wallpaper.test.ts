import { afterEach, expect, test } from 'bun:test';
import { mkdtemp, mkdir, readFile, rm, stat, symlink, writeFile } from 'node:fs/promises';
import { publishWallpaper } from '../shell/bin/login-wallpaper';
const directories: string[] = [];
afterEach(async () => { for (const path of directories.splice(0)) await rm(path, {recursive: true, force: true}); });
async function fixture() {
    const path = await mkdtemp('/tmp/tahow-wallpaper-'); directories.push(path);
    await mkdir(`${path}/target`);
    const result = Bun.spawnSync(['magick', '-size', '4x4', 'xc:blue', `${path}/wall paper.png`]);
    expect(result.exitCode).toBe(0);
    return path;
}
test('upload decodes local URLs, publishes a readable PNG and preserves it when a later upload fails', async () => {
    const path = await fixture();
    await publishWallpaper(Bun.pathToFileURL(`${path}/wall paper.png`).href, `${path}/target`);
    const output = `${path}/target/wallpaper.png`;
    const bytes = await readFile(output);
    expect(bytes.subarray(1, 4).toString()).toBe('PNG');
    expect((await stat(output)).mode & 0o777).toBe(0o644);
    await writeFile(`${path}/broken.png`, 'invalid');
    await expect(publishWallpaper(`${path}/broken.png`, `${path}/target`)).rejects.toThrow();
    expect(await readFile(output)).toEqual(bytes);
});
test('upload rejects missing setup, symlink destinations and unsupported content', async () => {
    const path = await fixture();
    await symlink(`${path}/target`, `${path}/link`);
    await expect(publishWallpaper(`${path}/wall paper.png`, `${path}/link`)).rejects.toThrow('setup-required');
    await expect(publishWallpaper(`${path}/wall paper.png`, `${path}/missing`)).rejects.toThrow();
    await writeFile(`${path}/image.svg`, '<svg/>');
    await expect(publishWallpaper(`${path}/image.svg`, `${path}/target`)).rejects.toThrow('unsupported-image');
});
