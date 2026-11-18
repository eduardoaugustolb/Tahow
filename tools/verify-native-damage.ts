import {mkdtempSync,mkdirSync,copyFileSync,rmSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
const temporary=mkdtempSync('/tmp/tahow-native-damage-');
const artifact=process.env.TAHOW_TEST_ARTIFACTS || temporary;
mkdirSync(artifact,{recursive:true});mkdirSync(temporary+'/ui');
copyFileSync(new URL('../shell/CompositorGlass.qml',import.meta.url),temporary+'/ui/CompositorGlass.qml');
copyFileSync(new URL('./verify-native-damage.qml',import.meta.url),temporary+'/shell.qml');
const app=Bun.spawn(['qs','-p',temporary+'/shell.qml'],{stdout:'pipe',stderr:'pipe',env:process.env});
try {
    let output='';const reader=app.stdout.getReader();
    const ready=(async()=>{while(true){const next=await reader.read();if(next.done)throw new Error('scene quit before presentation');output+=new TextDecoder().decode(next.value);if(output.includes('NATIVE_DAMAGE_READY'))return;}})();
    await Promise.race([ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('native damage presentation timeout')),5000))]);
    await Bun.sleep(700);
    execFileSync('grim',[artifact+'/before.png']);
    execFileSync('qs',['-p',temporary+'/shell.qml','ipc','call','tahowNativeDamage','change']);
    await Bun.sleep(350);
    execFileSync('grim',[artifact+'/after.png']);
    // Pixel inspection only; no image editing or capture of user content.
    const result=execFileSync('python3',['-c',`from PIL import Image
import sys
before=Image.open(sys.argv[1]).convert('RGB')
after=Image.open(sys.argv[2]).convert('RGB')
changed=sum(before.getpixel((x,y))!=after.getpixel((x,y)) for y in range(130,210) for x in range(180,230))
leaks=sum(max(abs(c-40) for c in after.getpixel((x,y)))>2 for y in range(100,240) for x in range(265,450))
assert changed>20, f'outside-only damage did not update refraction: {changed}'
assert leaks==0, f'native material escaped QML clip: {leaks}'
print(f'NATIVE_DAMAGE_OK refractedPixelsChanged={changed} clipLeaks={leaks}')`,artifact+'/before.png',artifact+'/after.png'],{encoding:'utf8'});
    console.log(result.trim());if(process.env.TAHOW_TEST_ARTIFACTS)console.log('Artifacts: '+artifact);
} finally {app.kill();await app.exited;rmSync(temporary,{recursive:true,force:true});}
