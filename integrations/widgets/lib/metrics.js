.pragma library
// Original Tahow samplers. Linux counters are cumulative; guests are already
// included in user/nice and must not be counted a second time.
function fraction(value) { return Math.max(0, Math.min(1, Number.isFinite(value) ? value : 0)); }
function unavailable() { return {available: false, value: 0, valueText: "—", detailText: ""}; }
function cpuCounters(text) {
    const line = String(text || "").split("\n").find(row => /^cpu\s/.test(row));
    if (!line) return null;
    const counters = line.trim().split(/\s+/).slice(1, 9).map(Number);
    if (counters.length < 4 || counters.some(value => !Number.isFinite(value) || value < 0)) return null;
    return {total: counters.reduce((sum, value) => sum + value, 0), idle: counters[3] + (counters[4] || 0)};
}
function cpuUsage(previous, current) {
    if (!previous || !current) return unavailable();
    const total = current.total - previous.total;
    const idle = current.idle - previous.idle;
    if (!(total > 0) || idle < 0 || idle > total) return unavailable();
    const value = fraction((total - idle) / total);
    return {available: true, value: value, valueText: Math.round(value * 100) + "%", detailText: ""};
}
function gib(kib) { return (kib / (1024 * 1024)).toFixed(1) + " GiB"; }
function memory(text) {
    const fields = {};
    for (const row of String(text || "").split("\n")) {
        const match = /^(\w+):\s+(\d+)\s+kB\s*$/.exec(row);
        if (match) fields[match[1]] = Number(match[2]);
    }
    const total = fields.MemTotal;
    const available = fields.MemAvailable !== undefined ? fields.MemAvailable
        : fields.MemFree !== undefined ? fields.MemFree + (fields.Buffers || 0) + (fields.Cached || 0) + (fields.SReclaimable || 0) - (fields.Shmem || 0) : NaN;
    if (!(total > 0) || !Number.isFinite(available)) return unavailable();
    const used = Math.max(0, Math.min(total, total - available));
    const value = fraction(used / total);
    return {available: true, value: value, valueText: gib(used), detailText: Math.round(value * 100) + "% · " + gib(total)};
}
function disk(text) {
    // POSIX df -Pk: filesystem, 1024-blocks, used, available, capacity, mount.
    const lines = String(text || "").trim().split("\n");
    for (let index = lines.length - 1; index > 0; index--) {
        const match = /^\S+\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.+)$/.exec(lines[index].trim());
        if (!match) continue;
        const total = Number(match[1]), used = Number(match[2]), percentage = Number(match[4]);
        if (!(total > 0) || used > total || percentage > 100) return unavailable();
        return {available: true, value: fraction(percentage / 100), valueText: percentage + "%", detailText: gib(used) + " / " + gib(total)};
    }
    return unavailable();
}
function sensorScore(sensor) {
    const chip = String(sensor.chip || "").toLowerCase();
    const label = String(sensor.label || "").toLowerCase();
    if (/coretemp|k10temp|zenpower|cpu_thermal|cpu-thermal/.test(chip)) return /package|tctl|tdie/.test(label) ? 120 : 110;
    if (/package|tctl|tdie|cpu/.test(label + " " + chip)) return 100;
    if (/gpu|amdgpu|nouveau/.test(label + " " + chip)) return 60;
    if (/nvme|drive|disk/.test(label + " " + chip)) return 20;
    return 40;
}
function temperature(sensors, unit) {
    if (!Array.isArray(sensors)) return unavailable();
    const valid = sensors.filter(sensor => sensor && Number.isFinite(sensor.celsius) && sensor.celsius >= -20 && sensor.celsius <= 150);
    valid.sort((a, b) => sensorScore(b) - sensorScore(a) || String(a.id || "").localeCompare(String(b.id || "")));
    if (!valid.length) return unavailable();
    const selected = valid[0];
    const fahrenheit = unit === "fahrenheit";
    const shown = fahrenheit ? selected.celsius * 9 / 5 + 32 : selected.celsius;
    return {available: true, value: fraction(selected.celsius / 100), valueText: Math.round(shown) + (fahrenheit ? " °F" : " °C"), detailText: selected.label || selected.chip || "", celsius: selected.celsius};
}
function interval(value) { return Math.round(Math.max(1, Math.min(60, Number.isFinite(Number(value)) ? Number(value) : 5))) * 1000; }
function artwork(url) {
    // Metadata may advertise arbitrary HTTP endpoints. No network capability is
    // needed: only local art is painted; remote covers use the UI fallback.
    const value = String(url || "");
    if (value.startsWith("/") && !value.startsWith("//")) return "file://" + value;
    return /^file:\/\/\//.test(value) || /^qrc:\//.test(value) ? value : "";
}
function sessionCommand(action) {
    return ["lock", "suspend", "reboot", "poweroff"].indexOf(action) >= 0 ? ["ryoku-shell", action] : [];
}
if (typeof module !== "undefined" && module.exports)
    module.exports = {fraction, unavailable, cpuCounters, cpuUsage, memory, disk, sensorScore, temperature, interval, artwork, sessionCommand};
