import { mkdir, mkdtemp, rename, rm, stat, readFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { CoverQueue } from './reload-cover-queue';

async function run(command: string[], env: Record<string, string> = {}) {
    const child = Bun.spawn(command, { env: { ...process.env, ...env }, stdout: 'ignore', stderr: 'pipe' });
    const timeout = setTimeout(() => child.kill('SIGKILL'), 120000);
    try {
        const error = await new Response(child.stderr).text();
        if (await child.exited !== 0) throw new Error(`${command[0]}: ${error.slice(-2500)}`);
    } finally { clearTimeout(timeout); }
}

export async function renderCover(input: string, output: string) {
    const source = input.startsWith('file:') ? Bun.fileURLToPath(input) : resolve(input);
    const info = await stat(source);
    if (!info.isFile() || info.size > 100 * 1024 * 1024 || !/\.(png|jpe?g|webp|bmp)$/i.test(source)) throw new Error('Unsupported wallpaper image');
    await mkdir(dirname(output), { recursive: true });
    const work = await mkdtemp(`${tmpdir()}/tahow-cover-`);
    try {
        await mkdir(`${work}/frames`);
        await mkdir(`${work}/runtime`, { mode: 0o700 });
        await run(['qs', '-p', resolve(import.meta.dir, '../reload/render.qml')], {
            QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'rhi', QSG_RHI_BACKEND: 'opengl',
            XDG_RUNTIME_DIR: `${work}/runtime`, TAHOW_COVER_WALLPAPER: Bun.pathToFileURL(source).href,
            TAHOW_COVER_FRAMES: `${work}/frames`,
        });
        await run(['ffmpeg', '-v', 'error', '-y', '-framerate', '24', '-i', `${work}/frames/%04d.png`,
            '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', `${work}/cover.mp4`]);
        if ((await stat(`${work}/cover.mp4`)).size > 20 * 1024 * 1024) throw new Error('Cover exceeds 20 MiB');
        // Stage beside the destination: atomic replacement also across filesystems.
        const staging = `${output}.pending`;
        try {
            await Bun.write(staging, Bun.file(`${work}/cover.mp4`));
            await rename(staging, output);
        } finally { await rm(staging, { force: true }); }
    } finally { await rm(work, { recursive: true, force: true }); }
}

export async function watchCover(output: string) {
    const queue = new CoverQueue();
    let completed = '';
    const ticker = setInterval(async () => {
        const path = queue.take(performance.now());
        if (!path) return;
        try {
            const file = path.startsWith('file:') ? Bun.fileURLToPath(path) : path;
            const fingerprint = createHash('sha256').update(await readFile(file)).digest('hex');
            if (fingerprint !== completed) {
                await renderCover(path, output);
                completed = fingerprint;
                console.log(`Cover ready: ${output}`);
            }
        } catch (error) { console.error(String(error)); }
        finally { queue.finish(); }
    }, 200);
    let socket: Awaited<ReturnType<typeof Bun.connect>> | undefined;
    const close = () => { clearInterval(ticker); socket?.end(); process.exit(0); };
    process.on('SIGTERM', close); process.on('SIGINT', close);
    // The subscription publishes the current wallpaper on connect, then changes.
    for (;;) {
        let disconnected!: () => void;
        const closed = new Promise<void>(done => disconnected = done);
        let buffer = '';
        try {
            socket = await Bun.connect({ unix: `${process.env.XDG_RUNTIME_DIR || '/tmp'}/ryogami.sock`, socket: {
                open(s) { s.write('subscribe wallpaper\n'); },
                data(_s, chunk) {
                    buffer += chunk.toString();
                    if (buffer.length > 1024 * 1024) { buffer = ''; return; }
                    let end: number;
                    while ((end = buffer.indexOf('\n')) >= 0) {
                        const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
                        try {
                            const message = JSON.parse(line);
                            const entry = message.default || Object.values(message.outputs || {})[0] as { path?: string };
                            if (entry?.path) queue.request(entry.path, performance.now());
                        } catch { /* Ignore unrelated frames. */ }
                    }
                },
                close() { disconnected(); }, error() { disconnected(); },
            } });
            await closed;
        } catch (error) { console.error(`Wallpaper subscription unavailable: ${String(error)}`); }
        await Bun.sleep(2000);
    }
}

if (import.meta.main) {
    const watch = process.argv[2] === '--watch';
    const fixed = process.argv[2] === '--fixed';
    const output = resolve(process.argv[watch ? 3 : 4] || `${process.env.XDG_CACHE_HOME || process.env.HOME + '/.cache'}/tahow-shell/reload-cover.mp4`);
    try {
        if (watch) await watchCover(output);
        else {
            if (process.argv[3] !== '--out') throw new Error('Usage: bun shell/bin/reload-cover.ts <wallpaper> --out <video.mp4> | --watch [video.mp4]');
            await renderCover(fixed ? resolve(import.meta.dir, '../reload/assets/tahow-glass-orbit.png') : process.argv[2], output);
        }
    } catch (error) { console.error(String(error)); process.exitCode = 1; }
}
