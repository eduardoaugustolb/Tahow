.pragma library

function minutes(value) {
    if (typeof value !== "string" || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) return -1;
    return Number(value.slice(0, 2)) * 60 + Number(value.slice(3));
}

function scheduleEnd(now, schedule) {
    const start = minutes(schedule?.start);
    const end = minutes(schedule?.end);
    if (start < 0 || end < 0 || start === end) return 0;

    const current = now.getHours() * 60 + now.getMinutes();
    const overnight = end < start;
    const active = overnight ? current >= start || current < end : current >= start && current < end;
    if (!active) return 0;

    const boundary = new Date(now);
    if (overnight && current >= start) boundary.setDate(boundary.getDate() + 1);
    return boundary.setHours(Math.floor(end / 60), end % 60, 0, 0);
}

function allowedApp(exceptions, desktopEntry, appName) {
    if (typeof exceptions !== "string") return false;
    const keys = [desktopEntry, appName].map(value => String(value || "").trim().toLowerCase());
    return exceptions.split(",").some(value => {
        const name = value.trim().toLowerCase();
        return name !== "" && keys.includes(name);
    });
}
