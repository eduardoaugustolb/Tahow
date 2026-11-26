import { expect, test } from "bun:test";
import { chmod, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

test("desktop wallpaper passes local paths and placement intact to the active backend", async () => {
    const temporary = await mkdtemp(join(tmpdir(), "tahow-wallpaper-"));
    try {
        const image = join(temporary, "fundo #1.png");
        const argumentsFile = join(temporary, "arguments");
        await Bun.write(image, "mock image");
        await Bun.write(join(temporary, "awww"), `#!/bin/sh
case "$1" in
    query) exit 0 ;;
    img) printf '%s\\n' "$@" > "$TAHOW_WALLPAPER_TEST_ARGUMENTS" ;;
    *) exit 1 ;;
esac
`);
        await chmod(join(temporary, "awww"), 0o755);
        const script = new URL("../shell/bin/desktop-wallpaper.ts", import.meta.url).pathname;
        const run = (file: string, mode: string) => Bun.spawnSync([process.execPath, script, file, mode], {
            env: {...Bun.env, PATH: temporary, TAHOW_WALLPAPER_TEST_ARGUMENTS: argumentsFile}
        });
        const applied = run(pathToFileURL(image).href, "fit");
        expect(applied.success).toBe(true);
        expect(JSON.parse(applied.stdout.toString())).toBe(image);
        const args = await Bun.file(argumentsFile).text();
        expect(args.split("\n")).toEqual(["img", "--resize", "fit", "--", image, ""]);
        expect(run(pathToFileURL(image).href, "invalid").success).toBe(false);
        expect(run(join(temporary, "missing.png"), "crop").success).toBe(false);
        expect(await Bun.file(argumentsFile).text()).toBe(args);
    } finally {
        await rm(temporary, {recursive: true, force: true});
    }
});
