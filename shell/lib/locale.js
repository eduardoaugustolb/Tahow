.pragma library
// Pure locale policy, shared by the standalone shell and the Ryoku lockscreen.
function normalize(value) {
    const code = String(value || "").trim().toLowerCase().replace(/[_ .-]/g, "");
    if (/^pt(?:br|pt|$)/.test(code) || code.indexOf("portugu") >= 0) return "pt-BR";
    return "en-US";
}
function isAutomatic(value) {
    const code = String(value || "").trim().toLowerCase();
    return !code || code === "auto" || code === "system";
}
function resolve(selected, inherited, system) {
    return normalize(!isAutomatic(selected) ? selected : !isAutomatic(inherited) ? inherited : system);
}
function translate(catalogs, locale, key, args) {
    if (key === undefined || key === null) return "";
    const source = String(key);
    const local = catalogs[normalize(locale)] || {};
    const fallback = catalogs["en-US"] || {};
    let value = Object.prototype.hasOwnProperty.call(local, source) ? local[source]
        : Object.prototype.hasOwnProperty.call(fallback, source) ? fallback[source] : source;
    if (args) for (const name in args) value = value.split("{" + name + "}").join(String(args[name]));
    return value;
}
