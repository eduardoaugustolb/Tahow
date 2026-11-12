import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const root = resolve(import.meta.dir, '..');
const hash = (data: string | Buffer) => createHash('sha256').update(data).digest('hex');
const products = [
  { category: 'barstyles', source: 'shell', name: 'Tahow', summary: 'Modular Quickshell subshell with liquid-glass surfaces' },
  { category: 'launchers', source: 'integrations/ryostore/launcher', name: 'Tahow Palette', summary: 'The Tahow application palette, sharing its preferences' },
  { category: 'lockscreens', source: 'integrations/ryostore/lockscreen', name: 'Tahow Lock', summary: 'Tahow lock visuals with host-owned authentication' },
];
export function exportRyostore(targetPath: string) {
  const target = resolve(targetPath);
  // Validate every registration before writing any product or retiring an alias.
  const registrations = products.map(product => {
    const { category } = product;
    const registryPath = `${target}/${category}/registry.json`;
    if (!existsSync(registryPath)) throw new Error(`Not a Ryostore catalogue: ${registryPath}`);
    const registry = JSON.parse(readFileSync(registryPath, 'utf8'));
    const entry = registry[category]?.find((row: {id: string}) => row.id === 'tahoe-shell');
    if (!entry) throw new Error(`Register ${category}/tahoe-shell before exporting; preview and catalogue review are required.`);
    return { product, registryPath, registry, entry };
  });
  for (const { product, registryPath, registry, entry } of registrations) {
    const { category } = product;
    const destination = `${target}/${category}/tahoe-shell`;
    mkdirSync(destination, { recursive: true });
    cpSync(`${root}/${product.source}`, destination, { recursive: true });
    Object.assign(entry, { name: product.name, summary: product.summary, upstream: 'https://github.com/eduardoaugustolb/Tahow', lastUpdated: new Date().toISOString().slice(0, 10) });
    const files: string[] = [];
    function walk(base = '') {
      for (const name of readdirSync(`${destination}/${base}`).sort()) {
        const path = base ? `${base}/${name}` : name;
        if (statSync(`${destination}/${path}`).isDirectory()) walk(path);
        else if (path !== 'manifest.json') files.push(path);
      }
    }
    walk();
    const manifest = {
      schema: 1, id: 'tahoe-shell', category, version: entry.version,
      destination: category === 'lockscreens' ? 'qylock/themes/tahoe-shell' : `ryoku/${category}/tahoe-shell`,
      license: 'AGPL-3.0',
      files: files.sort().map(source => {
        const bytes = readFileSync(`${destination}/${source}`);
        return { source, destination: category === 'lockscreens' && source.startsWith('content/') ? source.slice(8) : source, mode: '0644', size: bytes.length, sha256: hash(bytes), install: !source.startsWith('assets/') };
      }),
    };
    const text = JSON.stringify(manifest, null, 2) + '\n';
    writeFileSync(`${destination}/manifest.json`, text);
    entry.manifestSha256 = hash(text);
    if (category === 'launchers') {
      // Retire the separate pre-Tahow palette listing. Keep its directory and
      // manifest intact: installed receipts still own those files, and removal
      // must remain the store's responsibility rather than this source exporter.
      registry[category] = registry[category].filter((row: { id: string }) => row.id !== 'tahoe');
    }
    writeFileSync(registryPath, JSON.stringify(registry, null, 2) + '\n');
    console.log(`Exported ${category}/tahoe-shell (${files.length} files)`);
  }
}

if (import.meta.main) {
  const index = process.argv.indexOf('--to');
  if (index < 0 || !process.argv[index + 1]) throw new Error('Usage: bun tools/export-ryostore.ts --to /path/to/ryostore');
  exportRyostore(process.argv[index + 1]);
}
