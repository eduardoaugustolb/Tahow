import { readdirSync, statSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const formatter = process.env.QMLFORMAT || (existsSync('/usr/lib/qt6/bin/qmlformat') ? '/usr/lib/qt6/bin/qmlformat' : Bun.which('qmlformat'));
if (!formatter || !existsSync(formatter)) throw new Error('Qt 6 qmlformat is required for the QML syntax check.');
let count = 0;
function walk(dir: string) {
  for (const file of readdirSync(dir)) {
    const path = `${dir}/${file}`;
    if (statSync(path).isDirectory()) walk(path);
    else if (file.endsWith('.qml')) {
      execFileSync(formatter, [path], { stdio: ['ignore', 'ignore', 'pipe'] });
      count++;
    }
  }
}
walk('shell'); walk('integrations');
execFileSync(process.execPath, ['tools/sync-i18n.ts', '--check'], { stdio: 'inherit' });
for (const file of ['LICENSE', 'NOTICE.md', 'README.md', 'CONTRIBUTING.md', 'SECURITY.md', 'AGENTS.md']) {
  if (!existsSync(file)) throw new Error(`Missing ${file}`);
}
console.log(`QML syntax OK: ${count} files; generated translations and project documents OK.`);
