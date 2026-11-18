// Run inside an isolated Hyprland with the matching plugin loaded. No auth or real user content.
import {mkdtempSync,mkdirSync,copyFileSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const temporary=mkdtempSync('/tmp/tahow-compositor-glass-');
try {
    mkdirSync(`${temporary}/ui`);
    copyFileSync(new URL('../shell/CompositorGlass.qml',import.meta.url),`${temporary}/ui/CompositorGlass.qml`);
    copyFileSync(new URL('./verify-compositor-glass.qml',import.meta.url),`${temporary}/shell.qml`);
    const output=execFileSync('qs',['-p',`${temporary}/shell.qml`],{env:process.env,encoding:'utf8',timeout:10000,stdio:['ignore','pipe','pipe']});
    if(!output.includes('NATIVE_GLASS_OK')||output.includes('NATIVE_GLASS_FAILED'))throw new Error(output);
    console.log(output.split('\n').filter(line=>line.includes('NATIVE_GLASS_')).join('\n'));
} finally {rmSync(temporary,{recursive:true,force:true});}
