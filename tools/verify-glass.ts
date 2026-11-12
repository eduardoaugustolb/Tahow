import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

// Run against a temporary source runtime, never a real lock session.
// Requires glass + screenCapture enabled in the effective palette/island settings.
const config = resolve(process.argv[2] || 'shell/shell.qml');
const screenshots = process.argv.includes('--screenshots');
const ipc = (...args: string[]) => execFileSync('qs', ['-p', config, 'ipc', 'call', ...args], { encoding: 'utf8' });
const state = () => JSON.parse(ipc('tahoe', 'state'));
async function until(predicate: (value: any) => boolean, message: string) {
  const end = Date.now() + 2200;
  while (Date.now() < end) {
    const current = state();
    if (predicate(current)) return current;
    await Bun.sleep(40);
  }
  throw new Error(message);
}
try {
  for (let cycle = 0; cycle < 2; cycle++) {
    ipc('tahoe', 'openLauncher', '');
    await until(s => s.layout?.frameReady && !s.layout.captureFailed && s.captureCount === 0,
      'Palette did not present a captured frame. Check glass/capture preferences and compositor support.');
    if (screenshots && cycle === 0) {
      await Bun.sleep(500);
      execFileSync('grim', ['/tmp/tahow-palette-verified.png']);
    }
    ipc('tahoe', 'closeLauncher');
    await until(s => !s.layout, 'Palette did not release its surface.');
    ipc('tahoeIsland', 'open', '0');
    await until(s => s.islands.some((i: any) => i.mode === 'expanded' && i.backdropReady && !i.acquiringBackdrop)
      && s.captureCount === 0, 'Island did not present its backdrop.');
    if (screenshots && cycle === 0) {
      await Bun.sleep(500);
      execFileSync('grim', ['/tmp/tahow-island-verified.png']);
    }
    ipc('tahoeIsland', 'close');
    await until(s => s.islands.every((i: any) => i.mode !== 'expanded'), 'Island did not close.');
  }
  console.log('Glass runtime OK: two palette/island capture, presentation and close cycles; capture ownership released.');
} finally {
  ipc('tahoe', 'closeLauncher');
  ipc('tahoeIsland', 'close');
}
