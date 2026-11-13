import {expect,test} from 'bun:test';
import {buildWidgets,widgetProducts} from '../tools/build-widgets';
const text=await Bun.file('integrations/widgets/lib/metrics.js').text();
const metric=new Function(text.replace(/^\.pragma[^\n]*\n/, '')+'\nreturn {cpuCounters,cpuUsage,memory,disk,temperature,artwork,sessionCommand};')();
test('CPU deltas reject reset and warming-up counters',()=>{
 expect(metric.cpuUsage(null,{total:100,idle:70}).available).toBe(false);
 expect(metric.cpuUsage({total:100,idle:70},{total:200,idle:120}).value).toBe(.5);
 expect(metric.cpuUsage({total:200,idle:120},{total:100,idle:70}).available).toBe(false);
});
test('memory uses available RAM and temperature favors CPU',()=>{
 expect(metric.memory('MemTotal: 1000000 kB\nMemAvailable: 250000 kB').value).toBe(.75);
 expect(metric.memory('invalid').available).toBe(false);
 expect(metric.temperature([{id:'disk',chip:'nvme',celsius:40},{id:'cpu',label:'Tctl',celsius:71}],'celsius').valueText).toBe('71 °C');
 expect(metric.temperature([]).available).toBe(false);

 expect(metric.sessionCommand('rm -rf')).toEqual([]);
});
test('eight independent plugin products contain valid manifests and self-contained public imports',async()=>{
 buildWidgets();
 expect(widgetProducts).toHaveLength(8);
 for(const product of widgetProducts){
  const base='integrations/ryostore/widgets/tahow-'+product.kind;
  const manifest=await Bun.file(base+'/manifest.json').json();
  const distribution=await Bun.file(base+"/product-manifest.json").json();
  expect(distribution.files.some((file:any)=>file.source==="manifest.json" && file.install===true)).toBe(true);
  expect(manifest.hosts).toEqual(['desktopWidget']);
  expect(manifest.defaults.desktopWidget.bg).toBe('none');
  expect(manifest.metadata.settings.find((setting:any)=>setting.key==='material').default).toBe('simulated');
  expect(await Bun.file(base+'/content/shaders/liquid_glass.frag.qsb').exists()).toBe(true);
  if(product.kind==='clock')expect(manifest.metadata.settings.find((setting:any)=>setting.key==='clockStyle').default).toBe('card');
  expect(manifest.capabilities.network).toEqual(product.kind === "github" ? ["github-contributions-api.jogruber.de"] : product.kind === "media" ? ["*"] : []);
  expect(await Bun.file(base+'/assets/preview-widget.png').exists()).toBe(true);
  expect(await Bun.file(base+'/content/WidgetFace.qml').text()).not.toContain('import shell.');
  expect(await Bun.file(base+'/lib/messages.js').text()).not.toContain('sudo');
 }
});

const githubSource=await Bun.file('integrations/widgets/lib/github.js').text();
const github=new Function(githubSource.replace(/^\.pragma[^\n]*\n/,'')+'\nreturn {calendar,windowed,username};')();
test('GitHub shows no future days and keeps latest zero-contribution days',()=>{
 const data={contributions:[{date:'2026-11-10',count:4,level:2},{date:'2026-11-12',count:0,level:0},{date:'2026-11-13',count:8,level:4}]};
 const calendar=github.calendar(data,2026,'2026-11-12');
 expect(calendar.cells.filter((day:any)=>day.date).at(-1).date).toBe('2026-11-12');
 expect(calendar.total).toBe(4);
 const result=github.windowed(calendar,12,20,500);
 expect(result.weeks).toBe(20);
 expect(result.cells.filter((day:any)=>day.date).at(-1).date).toBe('2026-11-12');
 expect(result.cells.some((day:any)=>day.date==='2026-11-13')).toBe(false);
 expect(github.username('../invalid')).toBe('');
});

test('all Tahow widgets advertise their suite and persistent customization schema',async()=>{
 for(const product of widgetProducts){
  const manifest=await Bun.file('integrations/ryostore/widgets/tahow-'+product.kind+'/manifest.json').json();
  expect(manifest.set).toBe('Tahow Widgets');
  expect(manifest.dependencies.commands).toContain('ryoku-plugins-place');
  expect(await Bun.file('integrations/ryostore/widgets/tahow-'+product.kind+'/content/WidgetPreferences.qml').exists()).toBe(true);
 }
});

test('MPRIS artwork supports Spotify HTTPS covers and local files, rejecting unsafe schemes',()=>{
 const spotify='https://i.scdn.co/image/ab67616d0000b273daec894c14c0ca42d76eeb32';
 expect(metric.artwork(spotify)).toBe(spotify);
 expect(metric.artwork('https://example.com/cover.png?size=320')).toBe('https://example.com/cover.png?size=320');
 expect(metric.artwork('/tmp/cover.png')).toBe('file:///tmp/cover.png');
 expect(metric.artwork('file:///tmp/cover.png')).toBe('file:///tmp/cover.png');
 for(const url of ['http://example.com/art','javascript:alert(1)','data:image/svg+xml,test','https://','//example.com/art','https://user:pass@example.com/art'])expect(metric.artwork(url)).toBe('');
});
