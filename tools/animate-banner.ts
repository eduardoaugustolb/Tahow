import { cp, mkdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';

// Render the same glass flow and Sacramento refraction used by the reload
// screen. Animate the approved logo's silhouette with the same periodic field.
const root = resolve(import.meta.dir, '..');
const destination = `${root}/docs/brand/tahow-banner-v2`;
const work = await mkdtemp(`${tmpdir()}/tahow-brand-`);
async function run(args: string[], env = process.env) {
    const child = Bun.spawn(args, {env, stdout: 'pipe', stderr: 'pipe'});
    const timeout = setTimeout(() => child.kill('SIGKILL'), 90000);
    try {
        const [output, error] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text()]);
        if (await child.exited !== 0 || /Failed|Cannot|shader preparation failed/i.test(output + error)) throw new Error(output + error);
    } finally { clearTimeout(timeout); }
}
try {
    await mkdir(`${work}/frames`);
    await mkdir(`${work}/runtime`, {mode: 0o700});
    await run(['quickshell', '-p', `${root}/tools/brand/Render.qml`], {
        ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'rhi', QSG_RHI_BACKEND: 'opengl',
        XDG_RUNTIME_DIR: `${work}/runtime`, TAHOW_BANNER_ROOT: Bun.pathToFileURL(root).href.replace(/\/$/, ''),
        TAHOW_BANNER_FRAMES: `${work}/frames`, TAHOW_BANNER_COUNT: '96'
    });
    const input = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '24', '-i', `${work}/frames/%04d.png`];
    await cp(`${work}/frames/0000.png`, `${destination}.png`);
    await run([...input, '-filter_complex', 'fps=20,scale=960:352:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=3', '-loop', '0', `${destination}.gif`]);
    await run([...input, '-c:v', 'libwebp_anim', '-quality', '85', '-loop', '0', `${destination}.webp`]);
    await run([...input, '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', `${destination}.mp4`]);
    await mkdir(`${root}/website/public/brand`, {recursive: true});
    await cp(`${destination}.png`, `${root}/website/public/brand/tahow-banner-v2.png`);
    await cp(`${destination}.mp4`, `${root}/website/public/brand/tahow-banner-v2.mp4`);
    console.log('Rendered Sacramento + liquid-glass banner: PNG, GIF, WebP and MP4.');
} finally { await rm(work, {recursive: true, force: true}); }
