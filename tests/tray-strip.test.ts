import { expect, test } from 'bun:test';
const raw = await Bun.file(new URL('../shell/TrayStrip.qml', import.meta.url)).text();
// Drop line comments so documentation about the removed pattern does not trip
// the guard.
const source = raw.replace(/\/\/[^\n]*/g, '');

// Regression guard: a horizontal ListView whose width was bound to contentWidth
// crashed QML in QQuickItemView::maxYExtent during login, once tray items
// registered asynchronously. Keep the strip on a plain Row/Repeater.
test('tray strip does not reintroduce a ListView or a contentWidth-driven width', () => {
  expect(source).not.toMatch(/\bListView\b/);
  expect(source).not.toMatch(/\bcontentWidth\b/);
  expect(source).not.toMatch(/\bFlickable\b/);
});

test('tray strip lays out tray items in a Row of Repeater slots', () => {
  expect(source).toMatch(/\bRow\s*\{/);
  expect(source).toMatch(/\bRepeater\s*\{/);
  expect(source).toMatch(/model:\s*SystemTray\.items/);
});
