import { expect, test } from "bun:test";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("capture saves and copies the selected region and leaves the clipboard untouched on cancel", async () => {
    const home = mkdtempSync(join(tmpdir(), "tahow-capture-"));
    try {
        const commands = {
            slurp: 'test "$(readlink /proc/self/fd/0)" = /dev/null && test "${CANCEL:-0}" = 0 && printf "%s\\n" "-8,20 640x480"',
            grim: 'test "$1" = -g && test "$2" = "-8,20 640x480" && printf "image" > "$3"',
            "wl-copy": 'cat > "$HOME/clipboard"',
            "xdg-user-dir": "exit 1",
            "wf-recorder": 'test "$1" = --overwrite && test "$2" = --audio && test "$3" = -g && test "$4" = "-8,20 640x480" && test "$5" = -f && printf "video" > "$6"'
        };
        for (const [name, code] of Object.entries(commands)) {
            const executable = join(home, name);
            writeFileSync(executable, "#!/bin/sh\n" + code + "\n");
            chmodSync(executable, 0o700);
        }
        const env = { ...process.env, HOME: home, PATH: home + ":" + process.env.PATH };
        const args = ["sh", "shell/bin/capture.sh"];
        const capture = Bun.spawnSync([...args, "screenshot", "region"], { env });
        expect(capture.exitCode).toBe(0);
        expect(await Bun.file(capture.stdout.toString().trim()).text()).toBe("image");
        expect(await Bun.file(join(home, "clipboard")).text()).toBe("image");

        const cancelled = Bun.spawnSync([...args, "screenshot", "region"], { env: { ...env, CANCEL: "1" } });
        expect(cancelled.exitCode).toBe(3);
        expect(cancelled.stdout.toString()).toBe("");
        expect(await Bun.file(join(home, "clipboard")).text()).toBe("image");

        const recording = Bun.spawnSync([...args, "record", "region", "audio"], { env });
        expect(recording.exitCode).toBe(0);
        expect(await Bun.file(recording.stdout.toString().trim()).text()).toBe("video");
    } finally {
        rmSync(home, { recursive: true, force: true });
    }
});
