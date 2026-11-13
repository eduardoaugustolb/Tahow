import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

// Existing live session only. No lock/unlock or media-control actions.
const path = resolve(process.argv[2] || '/tmp/tahow-showcase-refresh');
await mkdir(path, {recursive: true});
const stateProcess=Bun.spawnSync(['ryoku','wm','state']);
if(stateProcess.exitCode)throw new Error('Cannot inspect the active workspace');
const before=JSON.parse(stateProcess.stdout.toString());
const output=before.outputs.find((output:any)=>output.focused);
if(!output)throw new Error('No focused output');
const originalWorkspace=String(output.activeWorkspace);
const captureWorkspace=process.env.TAHOW_CAPTURE_WORKSPACE || '9';
if(before.windows.some((window:any)=>String(window.workspace)===captureWorkspace))throw new Error('Capture workspace must have no application windows');
const config = `${process.env.HOME}/.config/quickshell/shell/shell.qml`;
async function run(args: string[]) {
    const child = Bun.spawn(args, {stdout: 'pipe', stderr: 'pipe'});
    const error = await new Response(child.stderr).text();
    if (await child.exited) throw new Error(`${args[0]}: ${error}`);
}
const ipc = (...args: string[]) => run(['quickshell','ipc','-p',config,'call',...args]);
async function capture(name: string) {
    await run(['ryoku','wm','act','workspace.focus',captureWorkspace]);
    await Bun.sleep(2300); // Let workspace OSD and springs settle before capture.
    await run(['grim','-o',output.name,`${path}/${name}.png`]);
    console.log(name);
}
try {
    await ipc('tahoe','closeSettings');
    await ipc('tahoe','closeLauncher');
    await ipc('tahoeIsland','close');
    await capture('island-collapsed');
    await capture('widgets');
    for (const [tab,name] of ['island-home','island-media','island-controls','island-timer'].entries()) {
        await ipc('tahoeIsland','open',String(tab));
        await capture(name);
    }
    await ipc('tahoeIsland','close');
    await ipc('tahoe','openLauncher','');
    await capture('command-palette');
    await ipc('tahoe','closeLauncher');
    for (const page of ['general','island','palette','lockscreen','system','shortcuts','glass']) {
        await ipc('tahoe','settingsTab',page);
        await capture(`settings-${page}`);
    }
} finally {
    await ipc('tahoe','closeSettings');
    await ipc('tahoe','closeLauncher');
    await ipc('tahoeIsland','close');
    // Return to the workspace that was active before the capture request.
    await run(['ryoku','wm','act','workspace.focus',originalWorkspace]);
}
