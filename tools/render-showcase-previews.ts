import { cp, mkdir, mkdtemp, rm, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dir,'..');
const target=resolve(process.argv[2] || '/tmp/tahow-showcase-refresh');
const temporary=await mkdtemp('/tmp/tahow-preview-');
try {
 await mkdir(target,{recursive:true});
 await cp(`${root}/shell`,`${temporary}/shell`,{recursive:true});
 await cp(`${root}/integrations/widgets`,`${temporary}/widgets`,{recursive:true});
 await Bun.write(`${temporary}/shell.qml`,await readFile(`${root}/tools/showcase/Preview.qml`));
 // Preview processes read a copy of the user's preferences and cannot write back.
 await mkdir(`${temporary}/config/tahow-shell`,{recursive:true});
 const preferences=await Bun.file(`${process.env.XDG_CONFIG_HOME || process.env.HOME+'/.config'}/tahow-shell/settings.json`).json();
 preferences.language='pt-BR';preferences.takeover=false;preferences.notifications=false;
 preferences.overrides={...preferences.overrides,island:{...preferences.overrides?.island,notifications:false}};
 await Bun.write(`${temporary}/config/tahow-shell/settings.json`,JSON.stringify(preferences));
 for(const mode of ['widgets','lockscreen','notifications','media-peek']) {
  const process=Bun.spawn(['quickshell','-p',`${temporary}/shell.qml`],{env:{...Bun.env,XDG_CONFIG_HOME:`${temporary}/config`,QT_QPA_PLATFORM:'offscreen',QT_QUICK_BACKEND:'rhi',QSG_RHI_BACKEND:'opengl',TAHOW_PREVIEW:mode,TAHOW_OUTPUT:`${target}/${mode}.png`},stdout:'pipe',stderr:'pipe'});
  const timer=setTimeout(()=>process.kill('SIGKILL'),18000);
  const [out,error]=await Promise.all([new Response(process.stdout).text(),new Response(process.stderr).text()]);
  const status=await process.exited;clearTimeout(timer);
  if(status || !await Bun.file(`${target}/${mode}.png`).exists())throw new Error(out+error);
  console.log(`${mode}: saved`);
  if(/Cannot|Error|Failed/.test(out+error))console.log((out+error).slice(-1800));
 }
}finally{await rm(temporary,{recursive:true,force:true});}
