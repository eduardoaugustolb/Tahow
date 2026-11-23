import {createConnection} from 'node:net';
const instance=process.env.HYPRLAND_INSTANCE_SIGNATURE;
if(!instance)throw new Error('Run inside the isolated Hyprland compositor under test');
const path=`${process.env.XDG_RUNTIME_DIR}/hypr/${instance}/tahow-glass.sock`;
const socket=createConnection(path);let pending:((message:any)=>void)[]=[];let input='';
socket.on('data',bytes=>{input+=bytes;let i;while((i=input.indexOf('\n'))>=0){const line=input.slice(0,i);input=input.slice(i+1);pending.shift()?.(JSON.parse(line));}});
await new Promise<void>((resolve,reject)=>{socket.once('connect',resolve);socket.once('error',reject);});
function send(message:any){socket.write(JSON.stringify(message)+'\n');}
async function query(message:any){const result=new Promise<any>(resolve=>pending.push(resolve));send(message);return await Promise.race([result,new Promise((_,reject)=>setTimeout(()=>reject(new Error('native protocol timeout')),2000))]);}
const region={op:'region',id:'bounded',target:'tahow-live-test',screen:'',x:0,y:0,width:100,height:100,radius:20,alpha:1};
try{
 const hello:any=await query({op:'hello',version:1});
 if(hello.version!==1 || hello.prism!==true)throw new Error('Native prism capability missing');
 for(let i=0;i<2000;i++)send({...region,x:i%10});
 let stats:any=await query({op:'stats'});if(stats.regions!==1)throw new Error('geometry updates accumulated regions');
 for(let i=0;i<100;i++)send({...region,id:'region-'+i});
 stats=await query({op:'stats'});if(stats.regions!==32)throw new Error('region budget not enforced');
 for(let i=0;i<100;i++)send({op:'remove',id:'region-'+i});send({op:'remove',id:'bounded'});
 stats=await query({op:'stats'});if(stats.regions!==0)throw new Error('removed regions retained');
 send({...region,width:-1});send({...region,target:'unsupported'});socket.write('{invalid json}\n');
 stats=await query({op:'stats'});if(stats.regions!==0)throw new Error('invalid regions accepted');
 console.log('NATIVE_PROTOCOL_OK updates=2000 maxRegions=32 retainedAfterRemove=0');
}finally{socket.destroy();}
