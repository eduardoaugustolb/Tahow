import { expect, test } from "bun:test";
import { runInNewContext } from "node:vm";
import { indexCatalog, search } from "../shell/lib/keymoji/Search.mjs";

const input = runInNewContext(
    (await Bun.file("shell/lib/input-panel.js").text()).replace(/^\.pragma library\n/, "")
    + "\n({ keyboardRows, arrowKeys, clipboardEntries })"
);

test("virtual keyboard includes Brazilian letters, accents and symbols", () => {
    expect(input.keyboardRows(false, false).flat()).toContain("ç");
    expect(input.keyboardRows(false, true).flat()).toContain("Ã");
    expect(input.keyboardRows(true, false).flat()).toContain("\\");
});

test("virtual arrow keys send the corresponding Wayland keysyms", () => {
    expect(input.arrowKeys.map(({ glyph, key }) => [glyph, key])).toEqual([
        ["←", "Left"], ["↑", "Up"], ["↓", "Down"], ["→", "Right"]
    ]);
});

test("clipboard previews only produce history entries with numeric IDs", () => {
    expect(input.clipboardEntries("51\tline with\ttab\ninvalid\tignored\n23\t<example>\n")).toEqual([
        { id: "51", preview: "line with\ttab" },
        { id: "23", preview: "<example>" }
    ]);
});

test("clipboard identifies image metadata and keeps other binary entries as text", () => {
    expect(input.clipboardEntries("52\t[[ binary data 3 MiB png 2880x1620 ]]\n53\t[[ binary data 1 KiB ]]")).toEqual([
        { id: "52", preview: "[[ binary data 3 MiB png 2880x1620 ]]", imageFormat: "png" },
        { id: "53", preview: "[[ binary data 1 KiB ]]" }
    ]);
});

test("Keymoji resolves Portuguese emoji queries without accents", async () => {
    const [catalog, pt, en] = await Promise.all(["emojis", "pt", "en"].map(
        name => Bun.file(`shell/lib/keymoji/data/${name}.json`).json()
    ));
    const rows = indexCatalog(catalog, pt, en);
    expect(rows.length).toBeGreaterThan(3900);
    expect(search(rows, "", "all", [], [])).toBe(rows);
    expect(search(rows, "coracao vermelho", "all", [], [])[0].e).toBe("❤️");
    expect(search(rows, "U+2764 U+FE0F", "all", [], [])[0].e).toBe("❤️");
    expect(search(rows, "", "recent", [], ["👋", "😀"]).map(row => row.e)).toEqual(["👋", "😀"]);
});
