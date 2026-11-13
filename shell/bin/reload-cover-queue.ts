// Trailing debounce + start-to-start throttle; only the latest request survives.
export class CoverQueue {
    pending = '';
    busy = false;
    due = 0;
    nextStart = 0;
    constructor(readonly debounce = 1500, readonly throttle = 30000) {}
    request(path: string, now: number) {
        if (!path) return;
        this.pending = path;
        this.due = now + this.debounce;
    }
    take(now: number): string | undefined {
        if (this.busy || !this.pending || now < Math.max(this.due, this.nextStart)) return;
        const path = this.pending;
        this.pending = '';
        this.busy = true;
        this.nextStart = now + this.throttle;
        return path;
    }
    finish() { this.busy = false; }
}
