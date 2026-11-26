import { expect, test } from 'bun:test';

const source = await Bun.file(new URL('../shell/lib/spotlight-query.js', import.meta.url)).text();
const { calculate, browserQuery } = new Function(
    source.replace(/^\.pragma[^\n]*\n/, '') + '\nreturn {calculate, browserQuery};'
)();

test('calculator handles precedence, exponentiation and decimal commas', () => {
    expect(calculate('(12 + 8) / 4')).toBe(5);
    expect(calculate('2 ^ 3 ^ 2')).toBe(512);
    expect(calculate('-2 ^ 2')).toBe(-4);
    expect(calculate('2,5 × 4')).toBe(10);
    expect(calculate('0.1 + 0.2')).toBe(0.3);
    expect(calculate('= 12')).toBe(12);
});

test('calculator rejects incomplete expressions, non-finite results and code', () => {
    for (const text of ['2+', '4/0', '1 / 0 ^ 0 + 1 / 0', '(1+)^0', '1 2 + 3', 'Math.sqrt(4)', '1+1;2', '25'])
        expect(calculate(text)).toBeNull();
});

test('browser opens HTTP sites and encodes regular or explicitly forced searches', () => {
    expect(browserQuery('example.org/docs')).toEqual({ url: 'https://example.org/docs', direct: true, forced: false });
    expect(browserQuery('https://example.org/?a=b')?.direct).toBeTrue();
    expect(browserQuery('? café & chá')).toEqual({
        url: 'https://duckduckgo.com/?q=caf%C3%A9%20%26%20ch%C3%A1', direct: false, forced: true,
    });
    expect(browserQuery('javascript:alert(1)')?.url).toStartWith('https://duckduckgo.com/?q=');
    expect(browserQuery('? ')).toBeNull();
});
