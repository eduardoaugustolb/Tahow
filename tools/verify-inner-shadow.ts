// Run only in an isolated compositor: captures synthetic content, never a user session.
import {cpSync,mkdtempSync,mkdirSync,copyFileSync,writeFileSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const temp=mkdtempSync('/tmp/tahow-inner-shadow-');
const artifacts=process.env.TAHOW_TEST_ARTIFACTS || temp;mkdirSync(artifacts,{recursive:true});
cpSync(new URL('../shell',import.meta.url),temp+'/shell',{recursive:true});
copyFileSync(new URL('./verify-inner-shadow.qml',import.meta.url),temp+'/shell.qml');
mkdirSync(temp+'/config/tahow-shell',{recursive:true});writeFileSync(temp+'/config/tahow-shell/settings.json',JSON.stringify({screenCapture:true,style:'glass',appearance:'dark'}));
const app=Bun.spawn(['qs','-p',temp+'/shell.qml'],{env:{...process.env,XDG_CONFIG_HOME:temp+'/config'},stdout:'pipe',stderr:'pipe'});
let output='';
const read=(async()=>{for await(const chunk of app.stdout)output+=new TextDecoder().decode(chunk);})();
const ipc=(...args:string[])=>execFileSync('qs',['-p',temp+'/shell.qml','ipc','call','tahowShadowTest',...args],{encoding:'utf8'}).trim();
const capture=(name:string)=>execFileSync('grim',[artifacts+'/'+name+'.png'],{timeout:5000});
try {
    await Bun.sleep(300); capture("warmup");
    for(let n=0;!output.includes('INNER_SHADOW_READY')&&n<70;n++){if(app.exitCode!==null)throw Error(output+await new Response(app.stderr).text());await Bun.sleep(100);}
    if(!output.includes('INNER_SHADOW_READY'))throw Error('Native material timeout: '+output+' state='+ipc('state'));
    await Bun.sleep(200);capture('shadow-on');ipc('shadow','0');await Bun.sleep(300);capture('shadow-off');
    // A per-region update must not alter the core or another program's uniforms.
    const pixels=execFileSync('python3',['-c',`from PIL import Image
import sys
on=Image.open(sys.argv[1]).convert('RGB');off=Image.open(sys.argv[2]).convert('RGB')
edge=bright=core=0
for y in range(100,300):
 for x in range(180,540):
  a=on.getpixel((x,y));b=off.getpixel((x,y))
  if a!=b:
   edge+=1
   if sum(b)>sum(a): bright+=1
   if 240<x<420 and 170<y<230: core+=1
assert edge>100,(edge,bright,core)
assert bright>edge*.95,(edge,bright,core)
assert core==0,(edge,bright,core)
print(f'INNER_SHADOW_PIXELS_OK changed={edge} brighter={bright} coreChanged={core}')`,artifacts+'/shadow-on.png',artifacts+'/shadow-off.png'],{encoding:'utf8'});console.log(pixels.trim());
    ipc('showSettings');await Bun.sleep(700);
    const windows=JSON.parse(execFileSync('hyprctl',['clients','-j'],{encoding:'utf8'}));const win=windows.find((w:any)=>w.title==='Tahow Preferences');if(!win)throw Error('No settings window');
    const address='address:'+win.address;
    execFileSync('hyprctl',['eval',`hl.dispatch(hl.dsp.window.move({x=330,y=150,relative=false,window="${address}"}))`]);await Bun.sleep(350);capture('settings-position');
    execFileSync('hyprctl',['eval',`hl.dispatch(hl.dsp.window.move({x=80,y=90,relative=false,window="${address}"}))`]);await Bun.sleep(350);capture('settings-moved');
    const outside=execFileSync('python3',['-c',`from PIL import Image
import sys
for path in sys.argv[1:]:
 im=Image.open(path).convert('RGB')
 # The old bug drew a 282x750 sidebar at the output origin.
 leaks=sum(max(abs(c-b) for c,b in zip(im.getpixel((x,y)),(192,200,208)))>3 for y in range(20,70) for x in range(20,260))
 assert leaks==0,(path,leaks)
print('SETTINGS_ORIGIN_OK moved twice; no detached material')`,artifacts+'/settings-position.png',artifacts+'/settings-moved.png'],{encoding:'utf8'});console.log(outside.trim());
}finally{app.kill();await app.exited;await read;const errors=await new Response(app.stderr).text();if(errors)console.log(errors);rmSync(temp,{recursive:true,force:true});}
