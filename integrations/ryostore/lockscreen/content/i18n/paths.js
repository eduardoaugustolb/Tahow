.pragma library
// Pure preferences-path policy, shared by the standalone shell and the
// Ryoku lockscreen companion.
//
// Tahow's canonical home is ~/.config/tahow-shell. Older DynamicIsland and
// Tahoe Shell builds wrote ~/.config/tahoe-shell, so that directory stays a
// readable fallback: the new path wins whenever it exists, otherwise the legacy
// path is adopted and becomes the canonical one.
//
// The path is always resolved against XDG_CONFIG_HOME when it is set.
function configHome(env) {
    const home = (env && env.HOME) || "";
    const xdg = env && env.XDG_CONFIG_HOME;
    return xdg && String(xdg).length > 0 ? String(xdg) : home + "/.config";
}

function canonicalDir(env) {
    return configHome(env) + "/tahow-shell";
}

function legacyDir(env) {
    return configHome(env) + "/tahoe-shell";
}

function canonicalSettingsPath(env) {
    return canonicalDir(env) + "/settings.json";
}

function legacySettingsPath(env) {
    return legacyDir(env) + "/settings.json";
}

// The canonical path always wins. The legacy path is only adopted when the
// canonical settings file does not exist yet, so a user who already migrated
// never sees old values win again.
function settingsPath(env, canonicalExists, legacyExists) {
    if (canonicalExists) return canonicalSettingsPath(env);
    if (legacyExists) return legacySettingsPath(env);
    return canonicalSettingsPath(env);
}
