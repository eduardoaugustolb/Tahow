import {mkdirSync} from 'node:fs';
const out=process.argv[2] || `${import.meta.dir}/build`;
mkdirSync(out,{recursive:true});
const flags=Bun.spawnSync(['pkg-config','--cflags','--libs','hyprland'],{stdout:'pipe',stderr:'inherit'});
if(flags.exitCode!==0)process.exit(flags.exitCode);
const result=Bun.spawnSync([process.env.CXX || 'c++','-std=c++26','-shared','-fPIC','-fno-gnu-unique','-O2','-Wall','-Wextra','-Wno-unused-parameter',`${import.meta.dir}/plugin.cpp`,'-o',`${out}/tahow-live-glass.so`,...flags.stdout.toString().trim().split(/\s+/)],{stdout:'inherit',stderr:'inherit'});
process.exit(result.exitCode);
