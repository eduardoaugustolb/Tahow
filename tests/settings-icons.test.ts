import { expect, test } from "bun:test";
import { runInNewContext } from "node:vm";

test("every Preferences sidebar icon comes from the Tahow SVG collection", async () => {
    const [mapping, settings] = await Promise.all([
        Bun.file("shell/lib/symbols.js").text(),
        Bun.file("shell/SettingsWindow.qml").text()
    ]);
    const symbols = runInNewContext(mapping.replace(/^\.pragma library\n/, "") + "\n({ has, image })");
    const pages = settings.split("readonly property var pages: [")[1].split("property string pageSearch")[0];
    const icons = [...pages.matchAll(/icon:\s*"([^"]+)"/g)].map(match => match[1]);
    expect(icons).toContain("keyboard");
    expect(icons).toContain("palette");
    for (const icon of [...new Set([...icons, "close"])]) {
        expect(symbols.has(icon)).toBe(true);
        for (const variant of ["regular", "filled"]) {
            const source = await Bun.file(`shell/icons/${variant}/${icon}.svg`).text();
            const svg = decodeURIComponent(symbols.image(icon, variant === "filled", "#000000").split(",")[1]);
            expect(source.trim()).toBe(svg);
        }
    }
});
