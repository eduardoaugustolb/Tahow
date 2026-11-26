.pragma library

var groups = [
    { id: "social", label: "Social", categories: ["Network", "Chat", "InstantMessaging", "Email"] },
    { id: "creativity", label: "Creativity", categories: ["Graphics", "AudioVideo", "Audio", "Video"] },
    { id: "productivity", label: "Productivity", categories: ["Office", "Finance", "Education", "Science", "Development"] },
    { id: "utilities", label: "Utilities", categories: ["System", "Utility", "Settings"] },
    { id: "other", label: "Other", categories: [] }
];

function category(entry) {
    var cats = entry.categories || [];
    for (var i = 0; i < groups.length - 1; i++)
        for (var j = 0; j < groups[i].categories.length; j++)
            if (cats.indexOf(groups[i].categories[j]) >= 0) return groups[i].id;
    return "other";
}

function normalize(text) {
    return String(text || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function results(entries, query, section, hidden, pinned) {
    var q = normalize(query).trim();
    return entries.filter(function(e) {
        if (!e || e.noDisplay || hidden.indexOf(e.id) >= 0) return false;
        if (!q && section === "suggestions") return pinned.indexOf(e.id) >= 0;
        if (!q && section !== "all" && category(e) !== section) return false;
        return !q || normalize([e.name, e.genericName, e.comment, (e.keywords || []).join(" ")].join(" ")).indexOf(q) >= 0;
    }).sort(function(a, b) {
        var ap = pinned.indexOf(a.id) >= 0, bp = pinned.indexOf(b.id) >= 0;
        var ax = q && normalize(a.name).startsWith(q), bx = q && normalize(b.name).startsWith(q);
        return Number(bx) - Number(ax) || Number(bp) - Number(ap) || a.name.localeCompare(b.name);
    });
}

function number(value, fallback, lo, hi) {
    return typeof value === "number" && isFinite(value) ? Math.max(lo, Math.min(hi, value)) : fallback;
}

function strings(value) {
    // Qt exposes persisted lists as iterable sequences in QML.
    return value && typeof value === "object" && typeof value[Symbol.iterator] === "function"
        ? Array.from(value).filter(function(v) { return typeof v === "string"; })
        : [];
}

function shelves(entries, section, query, pinned, columns) {
    if (query.trim() || section !== "all") {
        var group = groups.find(group => group.id === section);
        return [{ label: query.trim() ? "Search results" : (group ? group.label : "Suggestions"), entries: entries, start: 0 }];
    }
    var categories = groups.map(group => ({
        id: group.id, label: group.label, entries: entries.filter(entry => category(entry) === group.id)
    })).filter(group => group.entries.length);
    var fixed = entries.filter(entry => pinned.indexOf(entry.id) >= 0);
    var suggested = fixed.length ? fixed : categories.slice(0, columns).map(group => group.entries[0]);
    var start = 0;
    return [{ id: "suggestions", label: "Suggestions", entries: suggested }].concat(categories)
        .filter(group => group.entries.length).map(group => {
            var shown = group.entries.slice(0, columns);
            var shelf = { id: group.id, label: group.label, entries: shown,
                start: start, more: group.entries.length > columns };
            start += shown.length;
            return shelf;
        });
}

function shelfRows(sections, columns) {
    var rows = [];
    for (var shelf of sections) {
        for (var offset = 0; offset < shelf.entries.length; offset += columns)
            rows.push({ start: shelf.start + offset, length: Math.min(columns, shelf.entries.length - offset) });
    }
    return rows;
}
