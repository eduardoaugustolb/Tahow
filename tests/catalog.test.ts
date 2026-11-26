import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/lib/catalog.js', import.meta.url)).text();
const catalog = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {results,number,strings,shelves,shelfRows};')();
const apps = [
  { id: 'firefox', name: 'Firefox', keywords: ['browser'], categories: ['Network'] },
  { id: 'editor', name: 'Editor', comment: 'Firefox configuration editor', categories: ['Development'] },
  { id: 'music', name: 'Música', categories: ['Audio'] },
  { id: 'hidden', name: 'Hidden', noDisplay: true, categories: [] },
];
test('search ranks a name prefix before an incidental keyword, even if incidental app is pinned', () => {
  expect(catalog.results(apps, 'firefox', 'all', [], ['editor']).map((a: {id:string}) => a.id)).toEqual(['firefox', 'editor']);
});
test('search ignores accents and hidden entries, without mutating desktop entries', () => {
  expect(catalog.results(apps, 'musica', 'all', [], []).map((a: {id:string}) => a.id)).toEqual(['music']);
  expect(catalog.results(apps, '', 'all', ['editor'], []).some((a: {id:string}) => ['editor','hidden'].includes(a.id))).toBe(false);
  expect(apps).toHaveLength(4);
});
test('untrusted preference values have bounded layout fallbacks', () => {
  expect(catalog.number(Number.NaN, 7, 3, 16)).toBe(7);
  expect(catalog.number(1000, 7, 3, 16)).toBe(16);
  expect(catalog.strings(['ok', 12, null])).toEqual(['ok']);
  expect(catalog.strings(new Set(['ok', 12]))).toEqual(['ok']);
  expect(catalog.strings('ok')).toEqual([]);
});

test('launcher shelves show pinned suggestions and one row per category', () => {
  const entries = catalog.results(apps, '', 'all', [], ['editor', 'music']);
  const shelves = catalog.shelves(entries, 'all', '', ['editor', 'music'], 1);
  expect(shelves[0]).toMatchObject({ id: 'suggestions', entries: [apps[1]], start: 0, more: true });
  expect(catalog.shelves(entries, 'all', '', [], 2)[0].entries).toEqual([apps[0], apps[2]]);
  expect(shelves[1]).toMatchObject({ id: 'social', entries: [apps[0]], start: 1, more: false });
  expect(catalog.results(apps, '', 'suggestions', [], ['editor', 'music'])).toEqual([apps[1], apps[2]]);
  expect(catalog.shelves(entries, 'social', 'editor', [], 1)[0]).toMatchObject({
    label: 'Search results', entries, start: 0,
  });
});

test('keyboard rows stop at category boundaries and include partial rows', () => {
  expect(catalog.shelfRows([{ start: 0, entries: [apps[0]] }, { start: 1, entries: apps }], 3))
    .toEqual([{ start: 0, length: 1 }, { start: 1, length: 3 }, { start: 4, length: 1 }]);
});
