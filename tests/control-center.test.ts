import { expect, test } from "bun:test";
import { runInNewContext } from "node:vm";

const { normalize, controlIds, visibleControls, move } = runInNewContext(
    (await Bun.file("shell/lib/control-center.js").text()).replace(/^\.pragma library\n/, "")
    + "\n({ normalize, controlIds, visibleControls, move })"
);

test("missing and reset layouts preserve existing controls in their default order", () => {
    for (const layout of [undefined, null, {}, []]) {
        expect(visibleControls(normalize(layout), false).map(({ id }) => id)).toEqual(controlIds);
        expect(visibleControls(normalize(layout), true)).toEqual([]);
    }
});

test("orders visible controls by pin group, ignores invalid entries, and retains new defaults", () => {
    const layout = normalize([
        { id: "timer", pinned: true },
        { id: "mic", hidden: true, pinned: true },
        { id: "timer", hidden: true },
        { id: "colour", pinned: "true" },
        { id: "removed", pinned: true },
        null
    ]);

    expect(visibleControls(layout, true).map(({ id }) => id)).toEqual(["timer"]);
    expect(visibleControls(layout, false).map(({ id }) => id))
        .toEqual(["colour", "night-shift", "caffeine", "screenshot", "settings"]);
    expect(normalize(layout)).toEqual(layout);
});

test("moves a control without mutating its settings or wrapping past the list ends", () => {
    const layout = normalize([{ id: "timer", pinned: true }, { id: "mic", pinned: true }]);
    expect(visibleControls(move(layout, 1, -1), true).map(({ id }) => id)).toEqual(["mic", "timer"]);
    expect(visibleControls(layout, true).map(({ id }) => id)).toEqual(["timer", "mic"]);
    expect(move(layout, 0, -1)).toBe(layout);
    expect(move(layout, layout.length - 1, 1)).toBe(layout);
});
