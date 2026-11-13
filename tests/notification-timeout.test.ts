import {expect, test} from 'bun:test';

const source = await Bun.file('shell/Notifs.qml').text();
function functionSource(name: string) {
    const start = source.indexOf(`    function ${name}(`);
    const end = source.indexOf('\n    }', start) + 6;
    return source.slice(start, end);
}

test('critical and normal banners time out while notifications stay tracked', () => {
    const state = new Function('Config', 'NotificationUrgency', `
        let times = {}, popups = [], expiry = {};
        const dnd = false;
        ${functionSource('pushPopup')}
        ${functionSource('receive')}
        return {receive, snapshot: () => ({popups, expiry})};
    `)({island: {bannerTimeout: 5, notifSound: false}}, {Critical: 2});
    const before = Date.now();
    const normal = {id: 1, urgency: 1, tracked: false};
    const critical = {id: 2, urgency: 2, tracked: false};
    state.receive(normal);
    state.receive(critical);
    const {popups, expiry} = state.snapshot();
    expect(popups).toEqual([critical, normal]);
    for (const n of [normal, critical]) {
        expect(n.tracked).toBe(true);
        expect(expiry[n.id]).toBeGreaterThanOrEqual(before + 5000);
        expect(expiry[n.id]).toBeLessThanOrEqual(Date.now() + 5000);
    }
});
