import { expect, test } from 'bun:test';
import { CoverQueue } from '../shell/bin/reload-cover-queue';

test('bursts coalesce to the latest wallpaper after debounce', () => {
    const queue = new CoverQueue();
    queue.request('a', 0); queue.request('b', 1000);
    expect(queue.take(2499)).toBeUndefined();
    expect(queue.take(2500)).toBe('b');
});
test('rendering stays serial and a pending update waits for the throttle', () => {
    const queue = new CoverQueue();
    queue.request('a', 0); expect(queue.take(1500)).toBe('a');
    queue.request('b', 2000); queue.request('c', 4000);
    expect(queue.take(40000)).toBeUndefined();
    queue.finish();
    expect(queue.take(30000)).toBeUndefined();
    expect(queue.take(31500)).toBe('c');
});
test('a failed render can release the queue without losing its pending update', () => {
    const queue = new CoverQueue(10, 100);
    queue.request('a', 0); queue.take(10);
    queue.request('b', 20); queue.finish();
    expect(queue.take(110)).toBe('b');
});
