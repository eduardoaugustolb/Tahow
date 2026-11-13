// Build independent, self-contained Ryostore plugins from Tahow widget sources.
import { createHash } from 'node:crypto';
import { chmodSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';

const repository = resolve(import.meta.dir, '..');
export const widgetProducts = [
    { kind: 'github', name: 'GitHub', description: 'Public GitHub contribution calendar with year navigation.', commands: [] },
    { kind: 'cpu', name: 'CPU', description: 'Live processor utilization.', commands: [] },
    { kind: 'temperature', name: 'Temperature', description: 'Available hardware temperature sensors.', commands: ['bun'] },
    { kind: 'disk', name: 'Disk', description: 'Used and available space on the root filesystem.', commands: ['df'] },
    { kind: 'memory', name: 'Memory', description: 'Used and available system memory.', commands: [] },
    { kind: 'session', name: 'Session', description: 'Explicit lock, suspend and session actions.', commands: ['ryoku-shell'] },
    { kind: 'clock', name: 'Clock', description: 'Local time and date.', commands: [] },
    { kind: 'media', name: 'Media', description: 'Playback and controls for available MPRIS players.', commands: [] },
] as const;

const choice = (key: string, label: string, value: string, options: string[], group = 'Glass') => ({
    key, type: 'choice', label, group, default: value, options: options.map(value => ({ value, label: value })),
});
const slider = (key: string, label: string, value: number, min: number, max: number, step: number) => ({
    key, type: 'slider', label, group: 'Glass', default: value, min, max, step,
});
export function widgetSettings(kind: string) {
    const shared: object[] = [
        choice('material','Material','simulated',['simulated','liquid','none']),
        slider('bezel','Lens edge',14,0,40,1),
        slider('thickness','Refraction depth',24,0,60,1),
        slider('ior','Refractive index',1.5,1,2.5,0.01),
        slider('dispersion','RGB dispersion',0.08,0,0.2,0.005),
        slider('frost','Frost',8,0,30,0.5),
        {key:'contentWidth',type:'int',label:'Width',group:'Size',default:0,min:0,max:1600},
        {key:'contentHeight',type:'int',label:'Height',group:'Size',default:0,min:0,max:1000},
        choice('language', 'Language', 'auto', ['auto', 'en-US', 'pt-BR']),
        choice('appearance', 'Appearance', 'auto', ['auto', 'dark', 'light']),
        slider('glassOpacity', 'Glass opacity', 0.55, 0.15, 1, 0.01),
        { key: 'glassRim', type: 'toggle', label: 'Specular rim', group: 'Glass', default: true },
        { key: 'glassAccentTint', type: 'toggle', label: 'Tint glass with accent', group: 'Glass', default: true },
    ];
    if (['cpu', 'temperature', 'disk', 'memory'].includes(kind)) shared.push({
        key: 'refreshInterval', type: 'int', label: 'Refresh interval', group: 'Data', default: 5, min: 1, max: 60,
    });
    if (kind === 'temperature') shared.push(choice('unit', 'Units', 'celsius', ['celsius', 'fahrenheit'], 'Data'), {key: 'bunPath', type: 'text', label: 'Bun executable', group: 'Data', default: 'bun'});
    if (kind === 'clock') shared.push(
        {key:'clockCompact',type:'toggle',label:'Compact width',group:'Clock',default:false},
        choice('clockStyle', 'Style', 'card', ['card', 'bare'], 'Clock'),
        { key: 'use24h', type: 'toggle', label: '24-hour clock', group: 'Clock', default: true },
        { key: 'showSeconds', type: 'toggle', label: 'Show seconds', group: 'Clock', default: false },
    );
    if(kind === 'github')shared.push({key:'username',type:'text',label:'GitHub username',group:'GitHub',default:''},{key:'minWeeks',type:'int',label:'Minimum weeks',group:'GitHub',default:12,min:4,max:53},{key:'maxWeeks',type:'int',label:'Maximum weeks',group:'GitHub',default:53,min:4,max:53});
    return shared;
}

type BuildOptions = { sourceDir?: string; targetDir?: string; check?: boolean };
const digest = (bytes: Uint8Array | string) => createHash('sha256').update(bytes).digest('hex');
function filesIn(directory: string, base = ''): string[] {
    return readdirSync(resolve(directory, base)).sort().flatMap(name => {
        const path = base ? `${base}/${name}` : name;
        const stat = lstatSync(resolve(directory, path));
        if (stat.isSymbolicLink()) throw new Error(`Widget sources must not contain symlinks: ${path}`);
        return stat.isDirectory() ? filesIn(directory, path) : [path];
    });
}
export function buildWidgets(options: BuildOptions = {}) {
    const source = resolve(options.sourceDir || `${repository}/integrations/widgets`);
    const target = resolve(options.targetDir || `${repository}/integrations/ryostore/widgets`);
    for (const required of ['service/WidgetService.qml', 'content/WidgetFace.qml']) {
        if (!existsSync(`${source}/${required}`)) throw new Error(`Missing widget source: ${required}`);
    }
    const sourceFiles = filesIn(source).filter(path => /^(content|service|lib|assets|bin)\//.test(path));
    const outputs = new Map<string, Buffer>();
    for (const product of widgetProducts) {
        const id = `tahow-${product.kind}`;
        const output = new Map<string, Buffer>();
        const put = (path: string, bytes: Buffer | string) => output.set(path, Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes));
        for (const path of sourceFiles) {
            if (path === 'lib/messages.js' || path === 'lib/material.js' || path === 'lib/symbols.js' || path === 'lib/locale.js') continue;
            if (path === 'service/Main.qml' || path === 'content/Widget.qml') throw new Error(`Reserved generated wrapper: ${path}`);
            if (path.startsWith('bin/') && product.kind !== 'temperature') continue;
            if (/^assets\/preview-[^.]+\.(png|webp)$/.test(path)) continue;
            put(path, readFileSync(`${source}/${path}`));
        }
        for (const extension of ['png', 'webp']) {
            const preview = `${source}/assets/preview-${product.kind}.${extension}`;
            if (existsSync(preview)) put(`assets/preview-widget.${extension}`, readFileSync(preview));
        }
        // Original, self-contained Tahow helpers. No private desktop imports
        // or optical shader without a captured texture are packaged here.
        for (const name of ['material.js', 'symbols.js', 'locale.js']) put(`lib/${name}`, readFileSync(`${repository}/shell/lib/${name}`));
        const keys = ['CPU','Temperature','Disk','Memory','Unavailable','Local time','User','Session','Lock','Suspend','Restart','Shut Down','Click again to confirm','Session controls','Previous','Pause','Play','Next','Playback position','Not Playing','Start music in any MPRIS player','Set your GitHub username in widget settings','Loading contributions…','Unable to load contributions','contributions','Refresh','Settings'];
        keys.push(...widgetSettings(product.kind).flatMap((setting:any)=>[setting.label,setting.group,...(setting.options||[]).map((option:any)=>option.label)]));
        const catalogs: Record<string, Record<string,string>> = {};
        for (const code of ['en-US','pt-BR']) {
            const all = JSON.parse(readFileSync(repository+'/locales/'+code+'.json','utf8'));
            catalogs[code] = Object.fromEntries(keys.map(key=>[key,all[key] || key]));
        }
        put('lib/messages.js','.pragma library\n// Generated widget-only locale subset.\nvar catalogs = '+JSON.stringify(catalogs,null,2)+';\n');
        put('service/Main.qml', `import QtQuick\n\n// Generated by bun tools/build-widgets.ts.\nWidgetService { kind: "${product.kind}" }\n`);
        put('content/Widget.qml', `import QtQuick\n\n// Generated by bun tools/build-widgets.ts.\nWidgetFace { kind: "${product.kind}" }\n`);
        put('LICENSE', readFileSync(`${repository}/LICENSE`));
        put('NOTICE.md', readFileSync(`${repository}/NOTICE.md`));
        put('PROVENANCE.txt', `Generated from Tahow integrations/widgets by bun tools/build-widgets.ts.\nFunctional references: Ryoku Python shell usage/user/clock/music faces (AGPL-3.0). No private imports or runtime dependency.\nOriginal Tahow widget composition, material helper and geometric symbols: Eduardo Augusto and contributors, 2026.\nCombined distribution: AGPL-3.0-only; retain LICENSE and NOTICE.md.\nNo Apple or Icons8 assets are included. Liquid Glass reuses the attributed Ryoku shader via Tahow NativeGlass; it refracts the published wallpaper without screen capture.\n`);
        const readme = `# Tahow ${product.name}\n\n${product.description}\n\nIndependent Ryoku desktopWidget plugin. No Tahow subshell is required. Material variants: simulated glass, Liquid Glass refracting the published wallpaper, and no background. Liquid Glass does not capture the desktop or track windows; it falls back to simulated glass when no wallpaper is available. Existing settings remain unchanged, and simulated glass remains the default.\n\nReads pluginApi.pluginSettings with defaults. Settings and desktop placement are written by Ryoku's host; this plugin does not edit shared Tahow or host preferences. Right-click the tile to configure its material and available data options.\n\nCommands: ${product.commands.length ? product.commands.join(', ') : 'none'}. Network: ${product.kind === 'github' ? 'github-contributions-api.jogruber.de (public contributions)' : 'none'}. Privileged actions: none. ${product.kind === 'session' ? 'Session actions run only after explicit clicks.' : ''}\n${product.kind === 'cpu' || product.kind === 'memory' ? 'Reads Linux /proc counters; unavailable data is shown explicitly.' : product.kind === 'temperature' ? 'Reads available Linux /sys/class/hwmon and thermal sensors through the bundled Bun script.' : product.kind === 'disk' ? 'Reads filesystem capacity through df.' : product.kind === 'media' ? 'Reads MPRIS session bus state and local album art; playback controls run on explicit interaction.' : ''}\n\nInstall locally with \`ryoku plugin add /path/to/${id} --yes\`. In Stage Editor, add or move the desktop widget; drag to position, resize with the host handles, and right-click for settings. The manifest requests host backing \`none\` so the Tahow face supplies its own material. Runtime size comes from the content's implicit dimensions; the host adds its placement padding.\n\nGenerated source: https://github.com/eduardoaugustolb/Tahow. Do not hand-edit generated files.\n`;
        put('README.md',readme.split('\n').map(line=>line.trimEnd()).join('\n'));
        const settings = widgetSettings(product.kind);
        const manifest = {
            schema: 1, id, set: 'Tahow Widgets', category: 'plugins', version: '0.1.0', destination: `ryoku/plugins/${id}`,
            name: `Tahow ${product.name}`, author: 'Eduardo Augusto <eduardoaugustolimabueno423@gmail.com>',
            description: product.description, license: 'AGPL-3.0-only', official: false,
            tags: ['tahow', 'desktop-widget', 'glass', product.kind],
            hosts: ['desktopWidget'], entryPoints: { main: 'service/Main.qml', content: 'content/Widget.qml' },
            capabilities: { densities: ['compact', 'full'], colors: true, network: product.kind === 'github' ? ['github-contributions-api.jogruber.de'] : [], privileged: [] },
            defaults: { host: 'desktopWidget', label: `Tahow ${product.name}`, desktopWidget: { bg: 'none' } },
            dependencies: { commands: [...product.commands, 'ryoku-plugins-place'] }, metadata: { settings },
            files: [...output.keys()].sort().map(path => ({
                source: path, destination: path, mode: path.startsWith('bin/') ? '0755' : '0644',
                size: output.get(path)!.length, sha256: digest(output.get(path)!), install: !/^assets\/preview-widget\./.test(path),
            })),
        };
        put('manifest.json', JSON.stringify(manifest, null, 2) + '\n');
        const installed = output.get('manifest.json')!;
        const distribution = {schema:1,id,category:'plugins',version:manifest.version,destination:manifest.destination,license:manifest.license,files:[...manifest.files,{source:'manifest.json',destination:'manifest.json',mode:'0644',size:installed.length,sha256:digest(installed),install:true}]};
        put('product-manifest.json',JSON.stringify(distribution,null,2)+'\n');
        for (const [path, bytes] of output) outputs.set(`${id}/${path}`, bytes);
    }
    if (options.check) {
        for (const [path, bytes] of outputs) {
            if (!existsSync(`${target}/${path}`) || !readFileSync(`${target}/${path}`).equals(bytes)) throw new Error(`Outdated generated widget: ${path}`);
        }
        for (const product of widgetProducts) {
            const id = `tahow-${product.kind}`;
            for (const path of filesIn(`${target}/${id}`)) if (!outputs.has(`${id}/${path}`)) throw new Error(`Stale generated widget file: ${id}/${path}`);
        }
    } else {
        mkdirSync(target, { recursive: true });
        for (const product of widgetProducts) {
            const directory = `${target}/tahow-${product.kind}`;
            if (existsSync(directory)) for (const path of filesIn(directory)) {
                if (!outputs.has(`tahow-${product.kind}/${path}`)) rmSync(`${directory}/${path}`);
            }
        }
        for (const [path, bytes] of outputs) {
            const destination = resolve(target, path);
            if (relative(target, destination).startsWith('..')) throw new Error(`Unsafe widget path: ${path}`);
            mkdirSync(dirname(destination), { recursive: true });
            writeFileSync(destination, bytes);
            chmodSync(destination, path.includes('/bin/') ? 0o755 : 0o644);
        }
    }
    return widgetProducts.map(product => `tahow-${product.kind}`);
}

if (import.meta.main) console.log(`${process.argv.includes('--check') ? 'Verified' : 'Built'} ${buildWidgets({ check: process.argv.includes('--check') }).length} Tahow desktop widgets`);
