import { readdirSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const qsb = Bun.which('qsb') || '/usr/lib/qt6/bin/qsb';
let count = 0;
function walk(dir: string) {
  for (const name of readdirSync(dir)) {
    const path = `${dir}/${name}`;
    if (statSync(path).isDirectory()) walk(path);
    else if (name.endsWith('.frag')) { execFileSync(qsb, ['--qt6', '-o', `${path}.qsb`, path]); count++; }
  }
}
walk('shell'); walk('integrations');
console.log(`Built ${count} Qt 6 shaders`);
