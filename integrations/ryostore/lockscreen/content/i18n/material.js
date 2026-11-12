.pragma library
// Shared material color and intensity. Keep free of Qt so policy is testable.
function clamp(value, minimum, maximum, fallback) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(minimum, Math.min(maximum, number)) : fallback;
}
function opacity(value) { return clamp(value, 0.15, 1, 0.55); }
function amount(value, fallback) { return clamp(value, 0, 1, fallback); }
function base(dark) { return dark ? "#0f0f14" : "#f7f7fc"; }
function channels(color) {
    if (color && typeof color === "object" && Number.isFinite(color.r) && Number.isFinite(color.g) && Number.isFinite(color.b))
        return [color.r, color.g, color.b];
    const match = /^#([a-f\d]{6})$/i.exec(String(color || ""));
    if (!match) return [10 / 255, 132 / 255, 1];
    return [0, 2, 4].map(offset => parseInt(match[1].slice(offset, offset + 2), 16) / 255);
}
function tint(dark, accentEnabled, accent) {
    const neutral = channels(base(dark));
    const color = channels(accent);
    const mix = accentEnabled ? (dark ? 0.10 : 0.07) : 0;
    return "#" + neutral.map((value, index) => Math.round(clamp(value + (color[index] - value) * mix, 0, 1, value) * 255).toString(16).padStart(2, "0")).join("");
}
if (typeof module !== "undefined" && module.exports)
    module.exports = { base, tint, opacity, amount };
