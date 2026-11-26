import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/lib/catalog.js', import.meta.url)).text();
const catalog = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {results,number,strings,shelves,shelfRows,recentFiles};')();
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
test('search matches out-of-order terms, desktop IDs and missing letters', () => {
  const entries = [...apps, { id: 'org.kde.dolphin', name: 'Files', genericName: 'File Manager' }];
  const ids = (query: string) => catalog.results(entries, query, 'all', [], []).map((entry: {id: string}) => entry.id);
  expect(ids('configuration firefox')).toEqual(['editor']);
  expect(ids('dolphin manager')).toEqual(['org.kde.dolphin']);
  expect(ids('firfox')).toEqual(['firefox']);
  expect(ids('firefox impossible')).toEqual([]);
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

test('recent files use local bookmarks, matching decoded paths and sorting by recent access', () => {
  const bookmarks = [
    { href: 'file:///home/docs/Relat%C3%B3rio%20A.pdf', modified: '2026-01-01T10:00:00Z' },
    { href: 'file:///home/docs/Relat%C3%B3rio%20B.pdf', visited: '2026-02-01T10:00:00Z' },
    { href: 'file:///home/docs/broken%zz' },
    { href: 'file://remote/home/docs/report.pdf' },
    { href: 'file:////remote/home/docs/report.pdf' },
    { href: 'https://example.com/report.pdf' },
  ];
  expect(catalog.recentFiles(bookmarks, '')).toHaveLength(2);
  expect(catalog.recentFiles(bookmarks, 'relatorio').map((entry: { name: string }) => entry.name))
    .toEqual(['Relatório B.pdf', 'Relatório A.pdf']);
});
