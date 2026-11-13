import { cp, mkdir, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dir,'..');
await mkdir(`${root}/website/public/showcase`,{recursive:true});
for(const file of await readdir(`${root}/docs/showcase`)) {
 if(/\.(webp|mp4)$/.test(file))await cp(`${root}/docs/showcase/${file}`,`${root}/website/public/showcase/${file}`);
}
console.log('Synced showcase media into the documentation site.');
