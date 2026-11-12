import { expect, test } from 'bun:test';
const source = await Bun.file(new URL('../shell/lib/material.js', import.meta.url)).text();
const material = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {base,tint,opacity,amount};')();

test('accent-free glass uses the same neutral material in light and dark', () => {
    expect(material.tint(true, false, '#ff0000')).toBe(material.base(true));
    expect(material.tint(false, false, '#00ff00')).toBe(material.base(false));
    expect(material.base(true)).toBe('#0f0f14');
    expect(material.base(false)).toBe('#f7f7fc');
});

test('material accepts both Qt color channels and catalog hex accents', () => {
    for (const dark of [true, false]) {
        expect(material.tint(dark, true, {r: 10/255, g: 132/255, b: 1})).toBe(material.tint(dark, true, '#0a84ff'));
        expect(material.tint(dark, true, '#ff0000')).not.toBe(material.tint(dark, true, '#0000ff'));
    }
});

test('surface opacity and the independent lock tint have bounded intensities', () => {
    expect(material.opacity(0.55)).toBe(0.55);
    expect(material.opacity(-1)).toBe(0.15);
    expect(material.opacity(2)).toBe(1);
    expect(material.opacity(Number.NaN)).toBe(0.55);
    expect(material.amount(0.035, 0.035)).toBe(0.035);
    expect(material.amount(Number.NaN, 0.035)).toBe(0.035);
    expect(material.amount(-1, 0.035)).toBe(0);
});

test('the hosted lock ships exactly the same material policy', async () => {
    expect(await Bun.file(new URL('../integrations/ryostore/lockscreen/content/i18n/material.js', import.meta.url)).text()).toBe(source);
});
