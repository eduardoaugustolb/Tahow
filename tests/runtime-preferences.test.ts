import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/Runtime.qml', import.meta.url)).text();
const body = source.match(/function setDispersion\(amount: real\): void \{([\s\S]*?)^        \}/m)?.[1];
if (!body) throw new Error('Missing dispersion IPC handler');

test('dispersion update persists all scopes in one write and preserves other preferences', () => {
    let writes = 0;
    let overrides = {island: {style: 'glass'}, palette: {columns: 8}, lockscreen: {lockTint: 0.035}};
    const Config = {s: {
        get overrides() { return overrides; },
        set overrides(next) { writes++; overrides = next; }
    }};
    const set = new Function('Config', `return function(amount) {${body}}`)(Config);
    set(0.08);
    expect(writes).toBe(1);
    expect(overrides).toEqual({
        island: {style: 'glass', dispersion: 0.08},
        palette: {columns: 8, dispersion: 0.08},
        lockscreen: {lockTint: 0.035, lockDispersion: 0.08}
    });
    set(Number.NaN);
    expect(writes).toBe(1);
    set(2);
    expect(overrides.palette.dispersion).toBe(0.2);
});
