import {cpSync,readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {buildWidgets,widgetProducts} from './build-widgets';
const index=process.argv.indexOf('--to');
if(index<0||!process.argv[index+1])throw new Error('Usage: bun tools/export-widgets.ts --to /path/to/ryostore');
const target=resolve(process.argv[index+1]);
const path=target+'/plugins/registry.json';
const registry=JSON.parse(readFileSync(path,'utf8'));
if(!Array.isArray(registry.plugins))throw new Error('Not a plugin catalogue');
buildWidgets();
for(const product of widgetProducts){
 const id='tahow-'+product.kind;
 const source=resolve(import.meta.dir,'../integrations/ryostore/widgets',id);
 cpSync(source,target+'/plugins/'+id,{recursive:true});
 const manifest=readFileSync(source+'/product-manifest.json');
 const entry={id,name:'Tahow '+product.name,version:'0.1.0',path:'plugins/'+id,author:'Eduardo Augusto',official:false,license:'AGPL-3.0-only',upstream:'https://github.com/eduardoaugustolb/Tahow',summary:product.description,description:product.description,tags:['tahow','desktop-widget',product.kind],accent:'#9fc9ff',surface:'#172131',preview:'assets/preview-widget.png',screenshots:[],manifest:'product-manifest.json',manifestSha256:createHash('sha256').update(manifest).digest('hex'),lastUpdated:new Date().toISOString().slice(0,10)};
 const old=registry.plugins.findIndex((row:{id:string})=>row.id===id);
 if(old<0)registry.plugins.push(entry);else registry.plugins[old]={...registry.plugins[old],...entry};
}
writeFileSync(path,JSON.stringify(registry,null,2)+'\n');
console.log('Exported eight Tahow widgets; catalogue only, no publishing.');
