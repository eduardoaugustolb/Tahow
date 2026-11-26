import { expect, test } from 'bun:test';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readlinkSync, rmSync, symlinkSync } from 'node:fs';
import { createServer } from 'node:net';
import { endianness, tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { configureLogin } from '../tools/install-tahow-login';

test('selecting Tahow twice preserves and restores the previous display manager', () => {
    const directory = mkdtempSync(join(tmpdir(), 'tahow-login-'));
    try {
        const system = join(directory, 'system');
        const state = join(directory, 'state');
        const alias = join(system, 'display-manager.service');
        const override = join(system, 'greetd.service.d/90-tahow-login.conf');
        const previous = '../sddm.service';
        const service = '/usr/lib/systemd/system/greetd.service';
        mkdirSync(system);
        symlinkSync(previous, alias);

        configureLogin(system, state, { service, override: 'first release' });
        configureLogin(system, state, { service, override: 'second release' });
        expect(readlinkSync(alias)).toBe(service);
        expect(readFileSync(override, 'utf8')).toBe('second release');

        configureLogin(system, state);
        expect(readlinkSync(alias)).toBe(previous);
        expect(existsSync(override)).toBe(false);
    } finally {
        rmSync(directory, { recursive: true, force: true });
    }
});

const littleEndian = endianness() === 'LE';

for (const outcome of ['started', 'denied', 'cancelled']) {
    test(`greetd client handles simulated authentication ending in ${outcome}`, async () => {
        const directory = mkdtempSync(join(tmpdir(), 'tahow-greetd-'));
        const path = join(directory, 'socket');
        const requests: Record<string, unknown>[] = [];
        const prompt = { type: 'auth_message', auth_message_type: 'secret', auth_message: 'Simulated prompt' };
        const replies = [
            { type: 'auth_message', auth_message_type: 'info', auth_message: 'Simulated notice' },
            prompt,
            outcome === 'denied' ? { type: 'error', error_type: 'auth_error' } : { type: 'success' },
            { type: 'success' },
        ];
        const server = createServer(socket => {
            let pending = Buffer.alloc(0);
            socket.on('data', chunk => {
                pending = Buffer.concat([pending, chunk]);
                if (pending.length < 4) return;
                const size = new DataView(pending.buffer, pending.byteOffset, 4).getUint32(0, littleEndian);
                if (pending.length < size + 4) return;
                requests.push(JSON.parse(pending.subarray(4, 4 + size).toString()));
                pending = pending.subarray(4 + size);
                const body = Buffer.from(JSON.stringify(replies.shift()));
                const header = Buffer.alloc(4);
                new DataView(header.buffer, header.byteOffset, 4).setUint32(0, body.length, littleEndian);
                socket.write(header.subarray(0, 2));
                socket.write(Buffer.concat([header.subarray(2), body]));
            });
        });
        try {
            await new Promise<void>((done, reject) => server.once('error', reject).listen(path, done));
            const child = Bun.spawn([process.execPath, resolve('integrations/greetd/client.ts'), '/usr/bin/Hyprland'], {
                env: { ...process.env, GREETD_SOCK: path },
                stdin: new Blob([`"simulated-user"\n${outcome === 'cancelled' ? 'null' : '"test-only-response"'}\n`]),
                stdout: 'pipe',
                stderr: 'pipe',
                timeout: 3000,
            });
            const [code, output, errors] = await Promise.all([
                child.exited, new Response(child.stdout).text(), new Response(child.stderr).text(),
            ]);
            expect(code).toBe(0);
            expect(errors).toBe('');
            expect(output.trim().split('\n').map(line => JSON.parse(line).type)).toEqual(['info', 'secret', outcome]);
            expect(output).not.toContain('test-only-response');
            expect(requests).toEqual([
                { type: 'create_session', username: 'simulated-user' },
                { type: 'post_auth_message_response', response: null },
                ...(outcome === 'cancelled' ? [] : [{ type: 'post_auth_message_response', response: 'test-only-response' }]),
                outcome === 'started'
                    ? { type: 'start_session', cmd: ['/usr/bin/Hyprland'], env: ['XDG_SESSION_TYPE=wayland'] }
                    : { type: 'cancel_session' },
            ]);
        } finally {
            server.close();
            rmSync(directory, { recursive: true, force: true });
        }
    });
}
