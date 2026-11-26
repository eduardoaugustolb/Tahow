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
    const terms = q.split(/\s+/);
    return entries.filter(function(e) {
        if (!e || e.noDisplay || hidden.indexOf(e.id) >= 0) return false;
        if (!q && section === "suggestions") return pinned.indexOf(e.id) >= 0;
        if (!q && section !== "all" && category(e) !== section) return false;
        return true;
    }).map((entry, order) => ({
        entry,
        order,
        score: q ? searchScore(entry, q, terms) : 0,
        pinned: pinned.includes(entry.id)
    })).filter(hit => hit.score >= 0)
        .sort((a, b) => b.score - a.score || Number(b.pinned) - Number(a.pinned)
            || a.entry.name.localeCompare(b.entry.name) || a.order - b.order)
        .map(hit => hit.entry);
}

function searchScore(entry, query, terms) {
    const name = normalize(entry.name);
    if (name === query) return 1000;
    if (name.startsWith(query)) return 900;
    if (name.includes(query)) return 800;

    const words = name.split(/[^\p{L}\p{N}]+/u);
    const metadata = normalize([entry.id, entry.genericName, entry.comment, ...strings(entry.keywords)].join(" "));
    let score = 0;
    for (const term of terms) {
        if (words.some(word => word.startsWith(term))) score += 60;
        else if (name.includes(term)) score += 40;
        else if (metadata.includes(term)) score += 20;
        else if (term.length >= 3 && words.some(word => closeSubsequence(word, term))) score += 10;
        else return -1;
    }
    return score / terms.length;
}

function closeSubsequence(word, term) {
    if (word[0] !== term[0] || word.length > term.length + 3) return false;
    let matched = 0;
    for (const letter of word) {
        if (letter === term[matched] && ++matched === term.length) return true;
    }
    return false;
}

function recentFiles(bookmarks, query) {
    const q = normalize(query).trim();
    const terms = q.split(/\s+/);
    const files = [];
    for (const bookmark of bookmarks) {
        const url = bookmark.href;
        if (typeof url !== "string" || !url.startsWith("file:///") || url.startsWith("file:////")) continue;
        try {
            const path = decodeURIComponent(url.slice("file://".length));
            if (path.startsWith("//")) continue;
            const split = path.lastIndexOf("/");
            const name = path.slice(split + 1);
            if (!name) continue;
            const visited = Date.parse(bookmark.visited || bookmark.modified) || 0;
            const file = { name, comment: path.slice(0, split) || "/", fileUrl: url, glyph: "description", visited };
            if (!q || searchScore(file, q, terms) >= 0) files.push(file);
        } catch (_) {
            // Ignore malformed percent-encoded bookmarks.
        }
    }
    return files.sort((a, b) => b.visited - a.visited).slice(0, 40);
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
