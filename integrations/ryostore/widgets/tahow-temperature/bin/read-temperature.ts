#!/usr/bin/env bun
// Read-only Linux sensor discovery. No daemon, cache, writes, network, or shell.
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';
export type Sensor = {id: string; chip: string; label: string; celsius: number};
async function text(path: string) { try { return (await readFile(path, 'utf8')).trim(); } catch { return ''; } }
async function entries(path: string) { try { return (await readdir(path)).sort().slice(0, 128); } catch { return []; } }
export async function readSensors(hwmon = '/sys/class/hwmon', thermal = '/sys/class/thermal'): Promise<Sensor[]> {
    const result: Sensor[] = [];
    for (const dir of (await entries(hwmon)).filter(name => /^hwmon\d+$/.test(name))) {
        const base = join(hwmon, dir), chip = await text(join(base, 'name'));
        for (const file of (await entries(base)).filter(name => /^temp\d+_input$/.test(name))) {
            const raw = await text(join(base, file));
            if (!/^-?\d+$/.test(raw)) continue;
            const celsius = Number(raw) / 1000;
            if (!Number.isFinite(celsius) || celsius < -20 || celsius > 150) continue;
            const label = await text(join(base, file.replace('_input', '_label')));
            result.push({id: dir + '/' + file, chip, label, celsius});
        }
    }
    // Some ARM/laptop drivers expose CPU temperatures only as thermal zones.
    for (const dir of (await entries(thermal)).filter(name => /^thermal_zone\d+$/.test(name))) {
        const base = join(thermal, dir), chip = await text(join(base, 'type')), raw = await text(join(base, 'temp'));
        if (!/^-?\d+$/.test(raw)) continue;
        const celsius = Number(raw) / 1000;
        if (Number.isFinite(celsius) && celsius >= -20 && celsius <= 150) result.push({id: dir, chip, label: chip, celsius});
    }
    return result;
}
if (import.meta.main) console.log(JSON.stringify(await readSensors()));
