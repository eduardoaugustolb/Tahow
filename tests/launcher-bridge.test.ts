import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../integrations/ryostore/launcher/Main.qml', import.meta.url)).text();
// Run the bridge's actual show handler against a simulated host surface bus.
const body = source.match(/function show\(mon\) \{([\s\S]*?)^    \}/m)?.[1];
if (!body) throw new Error('Missing launcher show handler');

test('inactive subshell refuses to claim an open palette and explains the requirement', () => {
  const requests: unknown[] = [], warnings: string[] = [];
  const host = {
    subshellActive: false, shown: true, monitor: '',
    Shell: { ShellState: { requestSurface: (...args: unknown[]) => requests.push(args) } },
    console: { warn: (message: string) => warnings.push(message) },
  };
  const show = new Function('host', `with (host) { return function(mon) {${body}}; }`)(host);
  show('DP-1');
  expect(host.shown).toBe(false);
  expect(requests).toHaveLength(0);
  expect(warnings[0]).toContain('tahoe-shell');
});

test('active subshell routes to the preserved surface ID on the requested output', () => {
  const requests: unknown[] = [];
  const host = {
    subshellActive: true, shown: false, monitor: '',
    Shell: { ShellState: { requestSurface: (...args: unknown[]) => requests.push(args) } },
    console: { warn: () => { throw new Error('Unexpected inactive diagnostic'); } },
  };
  const show = new Function('host', `with (host) { return function(mon) {${body}}; }`)(host);
  show('DP-1');
  expect(host.shown).toBe(true);
  expect(host.monitor).toBe('DP-1');
  expect(requests).toEqual([['tahoe-palette', 'DP-1', {}]]);
});
