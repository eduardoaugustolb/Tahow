import { afterEach, expect, test } from 'bun:test';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { exportRyostore } from '../tools/export-ryostore';

const temporary: string[] = [];
afterEach(() => { for (const path of temporary.splice(0)) rmSync(path, { recursive: true, force: true }); });
function fixture() {
  const target = mkdtempSync(join(tmpdir(), 'tahow-catalogue-'));
  temporary.push(target);
  for (const category of ['barstyles', 'launchers', 'lockscreens']) {
    mkdirSync(join(target, category), { recursive: true });
    writeFileSync(join(target, category, 'registry.json'), JSON.stringify({ [category]: [
      { id: 'tahoe-shell', version: '0.1.0', preview: 'assets/preview.png' },
      { id: 'unrelated', name: 'Unrelated' },
      ...(category === 'launchers' ? [{ id: 'tahoe', name: 'Tahoe' }] : []),
    ] }));
  }
  mkdirSync(join(target, 'launchers/tahoe'));
  writeFileSync(join(target, 'launchers/tahoe/manifest.json'), 'legacy receipt manifest\n');
  return target;
}
const json = (path: string) => JSON.parse(readFileSync(path, 'utf8'));
const sha256 = (bytes: string | Buffer) => createHash('sha256').update(bytes).digest('hex');

test('export retires only the legacy listing, preserves receipts, and hashes shipped files', () => {
  const target = fixture();
  exportRyostore(target);
  const launchers = json(join(target, 'launchers/registry.json')).launchers;
  expect(launchers.map((row: { id: string }) => row.id)).toEqual(['tahoe-shell', 'unrelated']);
  expect(launchers[0].name).toBe('Tahow Palette');
  expect(launchers[0].preview).toBe('assets/preview.png');
  expect(readFileSync(join(target, 'launchers/tahoe/manifest.json'), 'utf8')).toBe('legacy receipt manifest\n');
  for (const category of ['barstyles', 'launchers', 'lockscreens']) {
    const directory = join(target, category, 'tahoe-shell');
    const manifestText = readFileSync(join(directory, 'manifest.json'), 'utf8');
    const manifest = JSON.parse(manifestText);
    const entry = json(join(target, category, 'registry.json'))[category][0];
    expect(entry.manifestSha256).toBe(sha256(manifestText));
    expect(manifest.id).toBe('tahoe-shell');
    expect(manifest.files.length).toBeGreaterThan(0);
    for (const file of manifest.files) {
      const bytes = readFileSync(join(directory, file.source));
      expect(file.sha256).toBe(sha256(bytes));
      expect(file.size).toBe(bytes.length);
      if (category === 'lockscreens' && file.source.startsWith('content/'))
        expect(file.destination).toBe(file.source.slice(8));
    }
  }
  const before = readFileSync(join(target, 'launchers/registry.json'), 'utf8');
  exportRyostore(target);
  expect(readFileSync(join(target, 'launchers/registry.json'), 'utf8')).toBe(before);
});

test('missing registration fails preflight before removing an alias or writing earlier products', () => {
  const target = fixture();
  const path = join(target, 'launchers/registry.json');
  const before = readFileSync(path, 'utf8');
  writeFileSync(join(target, 'lockscreens/registry.json'), '{"lockscreens":[]}');
  expect(() => exportRyostore(target)).toThrow('Register lockscreens/tahoe-shell');
  expect(readFileSync(path, 'utf8')).toBe(before);
  expect(() => readFileSync(join(target, 'barstyles/tahoe-shell/manifest.json'))).toThrow();
});
