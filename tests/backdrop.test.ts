import {expect, test} from 'bun:test';
const source = await Bun.file(new URL('../shell/lib/backdrop.js', import.meta.url)).text();
const policy = new Function(source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {size};')();

test('backing textures stay in budget on scaled, ultrawide and portrait outputs', () => {
    for (const [w,h] of [[1920,1080],[3840,2160],[7680,4320],[5120,1440],[1080,3840],[1,1],[0,0],[NaN,Infinity]]) {
        const s=policy.size(w,h);
        expect(s.width*s.height).toBeLessThanOrEqual(2073600);
        expect(Math.max(s.width,s.height)).toBeLessThanOrEqual(2048);
        expect(Math.min(s.width,s.height)).toBeGreaterThanOrEqual(1);
        if(w>1 && h>1) expect(Math.abs(s.width/s.height-w/h)).toBeLessThan(0.01);
    }
    expect(policy.size(1920,1080)).toEqual({width:1920,height:1080});
});
