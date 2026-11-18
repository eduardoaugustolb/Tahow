// Pure geometry verification: no capture, compositor plugin or user preferences.
import {mkdtempSync,mkdirSync,copyFileSync,rmSync} from 'node:fs';
import {spawnSync} from 'node:child_process';
const temporary=mkdtempSync('/tmp/tahow-compositor-geometry-');
try {
    mkdirSync(temporary+'/ui');
    copyFileSync(new URL('../shell/CompositorGlass.qml',import.meta.url),temporary+'/ui/CompositorGlass.qml');
    copyFileSync(new URL('./verify-compositor-clipping.qml',import.meta.url),temporary+'/shell.qml');
    const result=spawnSync('qs',['-p',temporary+'/shell.qml'],{env:{...process.env,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'software'},encoding:'utf8',timeout:5000,stdio:['ignore','pipe','pipe']});
    const output=(result.stdout || '')+(result.stderr || '');
    if(result.error || result.status !== 0)throw new Error(output || String(result.error));
    if(/non-bindable|non-notifiable/.test(output))throw new Error('Non-notifiable property read in geometry binding: '+output);
    if(!output.includes('COMPOSITOR_GEOMETRY_OK')||output.includes('COMPOSITOR_GEOMETRY_FAILED'))throw new Error(output);
    console.log(output.split('\n').find(line=>line.includes('COMPOSITOR_GEOMETRY_OK')));
} finally {rmSync(temporary,{recursive:true,force:true});}
