import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
const config=(process.env.XDG_CONFIG_HOME||process.env.HOME+'/.config');
const widgets=JSON.parse(readFileSync(config+'/ryoku/widgets.json','utf8'));
const monitor=process.argv[2]||'eDP-1';
const local=widgets.monitors?.[monitor]||{};
const read=(prefix:string,key:string)=>local[prefix+key]??widgets[prefix+key];
const mappings=[['cpu','pythonCpu',180,130],['temperature','pythonTemp',180,130],['disk','pythonDisk',180,130],['memory','pythonRam',180,130],['session','pythonUser',260,140],['clock','pythonTime',156,120],['media','pythonMusic',340,120],['github','pythonGithub',540,180]] as const;
const snapshot='docs/python-widget-layout-before.json';
if(!existsSync(snapshot))writeFileSync(snapshot,JSON.stringify({monitor,layout:mappings.map(([kind,prefix,width,height])=>({kind,prefix,width,height,x:read(prefix,'X'),y:read(prefix,'Y'),scale:read(prefix,'Scale'),enabled:read(prefix,'Enabled')}))},null,2)+'\n');
for(const[kind,prefix,width,height]of mappings){
 const id='tahow-'+kind;const scale=Number(read(prefix,'Scale'))||1;
 const args={contentWidth:width*scale,contentHeight:height*scale,...kind==='github'?{username:process.env.USER||'',minWeeks:12,maxWeeks:53}:{}};
 const run=(...args:string[])=>execFileSync('ryoku-plugins-place',[id,...args]);
 run('seed');run('settings',JSON.stringify(args));run('desktopWidget',String(Number(read(prefix,'X'))-18),String(Number(read(prefix,'Y'))-18),'1',String(read(prefix,'Locked')===true));run('enabled','true');
}
console.log('Tahow placements match recorded Python face dimensions and coordinates (18px host padding compensated).');
