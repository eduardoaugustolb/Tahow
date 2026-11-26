import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../integrations/ryostore/launcher/Main.qml', import.meta.url)).text();
// Run the bridge's actual show handler against a simulated host surface bus.
const body = source.match(/function show\(mon\) \{([\s\S]*?)^    \}/m)?.[1];
if (!body) throw new Error('Missing launcher show handler');

function makeHost(overrides: Record<string, unknown>) {
  const requests: unknown[] = [], warnings: string[] = [], opened: string[] = [];
  const host = {
    subshellActive: false, shown: false, monitor: '',
    runtime: { item: { show: (mon: string) => opened.push(mon) } },
    Shell: { ShellState: { requestSurface: (...args: unknown[]) => requests.push(args) } },
    console: { warn: (message: string) => warnings.push(message) },
    ...overrides,
  };
  const show = new Function('host', `with (host) { return function(mon) {${body}}; }`)(host);
  return { host, show, requests, warnings, opened };
}

test('active subshell hands the palette to the preserved surface ID on the requested output', () => {
  const { host, show, requests, opened } = makeHost({ subshellActive: true });
  show('DP-1');
  expect(host.shown).toBe(true);
  expect(host.monitor).toBe('DP-1');
  expect(requests).toEqual([['tahoe-palette', 'DP-1', {}]]);
  expect(opened).toHaveLength(0);
});

test('inactive subshell opens the standalone runtime directly, without claiming a host surface', () => {
  const { host, show, requests, warnings, opened } = makeHost({ subshellActive: false });
  show('DP-1');
  expect(host.shown).toBe(true);
  expect(host.monitor).toBe('DP-1');
  expect(opened).toEqual(['DP-1']);
  expect(requests).toHaveLength(0);
  expect(warnings).toHaveLength(0);
});

test('inactive subshell without an installed runtime explains the requirement instead of opening', () => {
  const { host, show, requests, warnings, opened } = makeHost({ subshellActive: false, runtime: { item: null } });
  show('DP-1');
  expect(host.shown).toBe(false);
  expect(opened).toHaveLength(0);
  expect(requests).toHaveLength(0);
  expect(warnings[0]).toContain('tahoe-shell');
});