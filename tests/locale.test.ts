import { describe, expect, test } from 'bun:test';
import { resolve } from 'node:path';
const root = resolve(import.meta.dir, '..');
const source = await Bun.file(`${root}/shell/lib/locale.js`).text();
const locale = Function(source.replace(/^\.pragma library\s*/, '') + '\nreturn { normalize, resolve, translate };')();
const en = await Bun.file(`${root}/locales/en-US.json`).json();
const pt = await Bun.file(`${root}/locales/pt-BR.json`).json();
describe('language selection', () => {
    test('normalizes Ryoku, BCP-47, Qt and compact spellings', () => {
        for (const code of ['pt', 'ptbr', 'pt_BR', 'pt-BR', 'ptPT', 'pt_BR.UTF-8', 'Português (Brasil)']) expect(locale.normalize(code)).toBe('pt-BR');
        for (const code of ['en', 'enUS', 'en_US', 'en-US', 'de_DE', '', null]) expect(locale.normalize(code)).toBe('en-US');
    });
    test('auto inherits Ryoku before consulting system locale', () => {
        expect(locale.resolve('auto', 'pt_BR', 'en_US')).toBe('pt-BR');
        expect(locale.resolve('auto', 'en', 'pt_BR')).toBe('en-US');
    });
    test('explicit preference overrides both Ryoku and system', () => {
        expect(locale.resolve('en-US', 'ptbr', 'pt_BR')).toBe('en-US');
        expect(locale.resolve('pt-BR', 'en', 'en_US')).toBe('pt-BR');
    });
    test('standalone and automatic inherited selections use system, then English', () => {
        for (const inherited of [undefined, '', 'auto', 'system']) expect(locale.resolve('auto', inherited, 'pt_BR')).toBe('pt-BR');
        expect(locale.resolve(undefined, undefined, 'ja_JP')).toBe('en-US');
        expect(locale.resolve('fr-FR', 'pt', 'pt')).toBe('en-US');
    });
});
describe('translation catalogs', () => {
    test('catalogs have identical keys and string values', () => {
        expect(Object.keys(pt).sort()).toEqual(Object.keys(en).sort());
        for (const [key, value] of Object.entries(pt)) { expect(typeof value).toBe('string'); expect(value).not.toBe(''); expect(en[key]).toBe(key); }
    });
    test('translations preserve interpolation parameters', () => {
        for (const key of Object.keys(en)) {
            const parameters = (text: string) => (text.match(/\{[A-Za-z][A-Za-z0-9]*\}/g) || []).sort();
            expect(parameters(pt[key])).toEqual(parameters(en[key]));
        }
        expect(locale.translate({'en-US': en, 'pt-BR': pt}, 'pt', 'H:{high}  L:{low}', {high: '25°', low: '18°'})).toBe('Máx:25°  Mín:18°');
    });
    test('covers each main user-facing component', () => {
        for (const key of ['Language', 'Appearance', 'Command Palette', 'Good Morning', 'Sound', 'Not Playing', 'Light Rain', 'Notification Center', 'Password', 'Touch sensor or enter password']) {
            expect(pt[key]).toBeDefined(); expect(pt[key]).not.toBe(en[key]);
        }
    });
    test('uses translated strings, English fallback and source fallback', () => {
        expect(locale.translate({'en-US': {hello: 'Hello'}, 'pt-BR': {}}, 'ptbr', 'hello')).toBe('Hello');
        expect(locale.translate({'en-US': en, 'pt-BR': pt}, 'pt_BR', 'Password')).toBe('Senha');
        expect(locale.translate({}, 'pt', 'Device name')).toBe('Device name');
        expect(locale.translate({}, 'en', null)).toBe('');
    });
    test('interpolates every occurrence without treating replacement as syntax', () => {
        expect(locale.translate({'en-US': {'Hi {name}, {name}': 'Hi {name}, {name}'}}, 'en', 'Hi {name}, {name}', {name: '$&'})).toBe('Hi $&, $&');
    });
    test('generated JS and packaged lockscreen locale match canonical sources', async () => {
        const run = Bun.spawn(['bun', 'tools/sync-i18n.ts', '--check'], { cwd: root, stdout: 'pipe', stderr: 'pipe' });
        expect(await run.exited).toBe(0);
        expect(await Bun.file(`${root}/integrations/ryostore/lockscreen/content/i18n/locale.js`).text()).toBe(source);
    });
});
