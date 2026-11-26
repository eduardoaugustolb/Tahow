.pragma library

var arrowKeys = [
    { glyph: "←", label: "Left arrow key", key: "Left" },
    { glyph: "↑", label: "Up arrow key", key: "Up" },
    { glyph: "↓", label: "Down arrow key", key: "Down" },
    { glyph: "→", label: "Right arrow key", key: "Right" }
];

function keyboardRows(symbols, uppercase) {
    const rows = symbols
        ? ["1234567890", "!@#$%¨&*()", "-_=+[]{}<>", "/\\|:;?~^`´"]
        : ["1234567890", "qwertyuiop", "asdfghjklç", "zxcvbnm,.?", "áàâãéêíóôõúü"];
    return rows.map(row => Array.from(uppercase ? row.toUpperCase() : row));
}

function clipboardEntries(output) {
    const entries = [];
    for (const line of output.split("\n")) {
        const match = /^(\d+)\t(.*)$/.exec(line);
        if (!match) continue;
        const entry = { id: match[1], preview: match[2] };
        const image = /^\[\[ binary data .* (png|jpeg|jpg|gif|webp|bmp|tiff) \d+x\d+ \]\]$/.exec(entry.preview);
        if (image) entry.imageFormat = image[1];
        entries.push(entry);
        if (entries.length === 40) break;
    }
    return entries;
}
