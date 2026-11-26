import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../shell/lib/quick-keys.js', import.meta.url)).text();
const quickKeys = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {resolve};')();
const defaults = { timer: '25m', mic: 'mic', screenshot: 'shot', focus: 'foco' };

test('Quick Keys use defaults for absent or malformed overrides', () => {
  expect(quickKeys.resolve(defaults, null)).toEqual(defaults);
  expect(quickKeys.resolve(defaults, { timer: '  WORK  ', mic: 7, focus: 'não perturbe' }))
    .toEqual({ ...defaults, timer: 'work' });
});

test('duplicate aliases from manual changes fall back to unique defaults', () => {
  expect(quickKeys.resolve(defaults, { timer: ' MIC ' })).toEqual(defaults);
});
