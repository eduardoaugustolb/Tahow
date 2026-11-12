import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/Config.qml', import.meta.url)).text();
function handler(name: string, argumentsList: string, context: Record<string, unknown>) {
    const body = source.match(new RegExp(`function ${name}\\([^)]*\\) \\{([\\s\\S]*?)^    \\}`, 'm'))?.[1];
    if (!body) throw new Error(`Missing Config.${name}`);
    return new Function('context', `with (context) { return function(${argumentsList}) {${body}}; }`)(context);
}

test('optical defaults are persistent in canonical and legacy adapters and inherited from General', () => {
    const defaults = {bezel: 6, thickness: 8, ior: 1.2, dispersion: 0.08};
    for (const [key, value] of Object.entries(defaults)) {
        expect(source).toContain(`${key}: ${value},`);
        expect(source.match(new RegExp(`property real ${key}: ${value}`, 'g'))).toHaveLength(2);
    }
    const adapter = {bezel: 14, thickness: 20, ior: 1.6, dispersion: 0.12, overrides: {
        island: {thickness: 30}, palette: {dispersion: 0.04}, lockscreen: {lockDispersion: 0.1}
    }};
    const effective = handler('effective', 'scope', {defaults, adapter});
    expect(effective('island')).toMatchObject({bezel: 14, thickness: 30, ior: 1.6, dispersion: 0.12});
    expect(effective('palette')).toMatchObject({bezel: 14, thickness: 20, ior: 1.6, dispersion: 0.04});
    expect(effective('lockscreen').lockDispersion).toBe(0.1);
});

test('resetting Glass overrides preserves other settings and scopes without mutating their originals', () => {
    const original = {island: {dispersion: 0.18, bezel: 12, topMargin: 9}, palette: {columns: 8}};
    const adapter = {overrides: original};
    const inheritKeys = handler('inheritKeys', 'scope, keys', {adapter});
    inheritKeys('island', ['dispersion', 'bezel']);
    expect(adapter.overrides).toEqual({island: {topMargin: 9}, palette: {columns: 8}});
    expect(original.island).toEqual({dispersion: 0.18, bezel: 12, topMargin: 9});
    const unchanged = adapter.overrides;
    inheritKeys('general', ['columns']);
    inheritKeys('palette', ['notPresent']);
    expect(adapter.overrides).toBe(unchanged);
    inheritKeys('island', ['topMargin']);
    expect(adapter.overrides).toEqual({palette: {columns: 8}});
});
