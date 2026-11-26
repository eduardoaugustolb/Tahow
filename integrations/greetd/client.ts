import { createConnection } from 'node:net';
import { endianness } from 'node:os';
import { createInterface } from 'node:readline';

const littleEndian = endianness() === 'LE';
const maxPayload = 64 * 1024;

async function run() {
    const path = process.env.GREETD_SOCK;
    const session = process.argv[2];
    if (!path || !session?.startsWith('/')) throw new Error('Missing greeter configuration');

    const socket = createConnection(path);
    const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
    const lines = input[Symbol.asyncIterator]();
    const chunks = socket[Symbol.asyncIterator]();
    let buffer = Buffer.alloc(0);
    async function read(size: number) {
        while (buffer.length < size) {
            const { done, value } = await chunks.next();
            if (done) throw new Error('greetd disconnected');
            buffer = Buffer.concat([buffer, value]);
        }
        const result = buffer.subarray(0, size);
        buffer = buffer.subarray(size);
        return result;
    }
    async function request(payload: object) {
        const body = Buffer.from(JSON.stringify(payload));
        if (body.length > maxPayload) throw new Error('Oversized request');
        const header = Buffer.alloc(4);
        new DataView(header.buffer, header.byteOffset, 4).setUint32(0, body.length, littleEndian);
        socket.write(Buffer.concat([header, body]));
        const length = await read(4);
        const size = new DataView(length.buffer, length.byteOffset, 4).getUint32(0, littleEndian);
        if (size > maxPayload) throw new Error('Oversized response');
        return JSON.parse((await read(size)).toString('utf8'));
    }
    function send(type: string, message = '') {
        process.stdout.write(JSON.stringify({ type, message }) + '\n');
    }

    try {
        const username = JSON.parse((await lines.next()).value ?? 'null');
        if (typeof username !== 'string' || !username || username.length > 256 || /[\x00-\x1f\x7f]/.test(username)) throw new Error('Invalid username');
        let reply = await request({ type: 'create_session', username });
        while (reply.type === 'auth_message') {
            const style = reply.auth_message_type;
            if (typeof reply.auth_message !== 'string') throw new Error('Invalid prompt');
            send(style, reply.auth_message);
            if (style === 'info' || style === 'error') {
                reply = await request({ type: 'post_auth_message_response', response: null });
                continue;
            }
            if (style !== 'secret' && style !== 'visible') throw new Error('Invalid prompt style');
            const answer = JSON.parse((await lines.next()).value ?? 'null');
            if (answer === null) {
                await request({ type: 'cancel_session' });
                send('cancelled');
                return;
            }
            if (typeof answer !== 'string') throw new Error('Invalid response');
            reply = await request({ type: 'post_auth_message_response', response: answer });
        }
        if (reply.type === 'success') {
            reply = await request({ type: 'start_session', cmd: [session], env: ['XDG_SESSION_TYPE=wayland'] });
            if (reply.type === 'success') {
                send('started');
                return;
            }
        }
        await request({ type: 'cancel_session' });
        send(reply.error_type === 'auth_error' ? 'denied' : 'unavailable');
    } finally {
        input.close();
        process.stdin.pause();
        socket.destroy();
    }
}

run().catch(() => {
    // Never include protocol payloads or exceptions in journal output.
    process.stdout.write('{"type":"unavailable"}\n');
});
