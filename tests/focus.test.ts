import { expect, test } from "bun:test";
import { runInNewContext } from "node:vm";

const { scheduleEnd, allowedApp } = runInNewContext(
    (await Bun.file("shell/lib/focus.js").text()).replace(/^\.pragma library\n/, "")
    + "\n({ scheduleEnd, allowedApp })"
);

test("daily and overnight schedules include the start and exclude the end", () => {
    const today = (hours: number, minutes: number) => new Date(2026, 10, 26, hours, minutes);
    const daytime = { start: "08:30", end: "13:15" };
    const overnight = { start: "22:00", end: "06:30" };

    expect(scheduleEnd(today(8, 29), daytime)).toBe(0);
    expect(scheduleEnd(today(8, 30), daytime)).toBe(today(13, 15).getTime());
    expect(scheduleEnd(today(13, 15), daytime)).toBe(0);
    expect(scheduleEnd(today(22, 0), overnight)).toBe(new Date(2026, 10, 27, 6, 30).getTime());
    expect(scheduleEnd(today(1, 0), overnight)).toBe(today(6, 30).getTime());
    expect(scheduleEnd(today(6, 30), overnight)).toBe(0);
    expect(scheduleEnd(today(8, 30), { start: "08:30", end: "08:30" })).toBe(0);
    expect(scheduleEnd(today(8, 30), { start: "08:30", end: "29:00" })).toBe(0);
});

test("Focus exceptions match whole app names or desktop IDs", () => {
    const exceptions = " org.mozilla.firefox, Thunderbird, ";
    expect(allowedApp(exceptions, "org.mozilla.Firefox", undefined)).toBe(true);
    expect(allowedApp(exceptions, "", "thunderbird")).toBe(true);
    expect(allowedApp(exceptions, "org.mozilla.firefoxbeta", "")).toBe(false);
    expect(allowedApp(exceptions, "", "")).toBe(false);
    expect(allowedApp([], "org.mozilla.firefox", undefined)).toBe(false);
});
