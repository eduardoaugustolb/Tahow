import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/lib/catalog.js', import.meta.url)).text();
const catalog = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {results,number,strings};')();
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
});
