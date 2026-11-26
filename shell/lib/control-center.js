.pragma library

var controlIds = ["night-shift", "caffeine", "timer", "mic", "screenshot", "colour", "settings"];

function normalize(layout) {
    const controls = [];
    const seen = new Set();
    for (const entry of Array.isArray(layout) ? layout : []) {
        if (!entry || !controlIds.includes(entry.id) || seen.has(entry.id)) continue;
        seen.add(entry.id);
        controls.push({ id: entry.id, hidden: entry.hidden === true, pinned: entry.pinned === true });
    }
    for (const id of controlIds) {
        if (!seen.has(id)) controls.push({ id, hidden: false, pinned: false });
    }
    return controls;
}

function visibleControls(layout, pinned) {
    return layout.filter(entry => !entry.hidden && entry.pinned === pinned);
}

function move(layout, index, offset) {
    const destination = index + offset;
    if (index < 0 || index >= layout.length || destination < 0 || destination >= layout.length) return layout;
    const reordered = layout.slice();
    const [entry] = reordered.splice(index, 1);
    reordered.splice(destination, 0, entry);
    return reordered;
}
