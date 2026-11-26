.pragma library

function normalize(value) {
    return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function valid(value) {
    return /^[a-z0-9]{1,12}$/.test(value);
}

function resolve(defaults, overrides) {
    const keys = {};
    for (const id of Object.keys(defaults)) {
        const candidate = normalize(overrides?.[id]);
        keys[id] = valid(candidate) ? candidate : defaults[id];
    }
    // A manually edited config may assign two actions to the same key.
    const values = Object.values(keys);
    return new Set(values).size === values.length ? keys : defaults;
}
