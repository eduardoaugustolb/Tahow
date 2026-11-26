import { fileURLToPath } from "node:url";

export async function applyWallpaper(image: string, resize: string) {
    const path = image.startsWith("file:") ? fileURLToPath(image) : image;
    if (!path.startsWith("/") || !await Bun.file(path).exists() || !["crop", "fit"].includes(resize)) {
        throw new Error("Invalid wallpaper");
    }

    const clients = ["awww", "swww"].filter(client => Bun.which(client));
    const run = (command: string[], timeout = 8000) => Bun.spawnSync(command, {
        stdout: "ignore", stderr: "ignore", timeout
    }).success;
    let client = clients.find(name => run([name, "query"], 300));
    if (!client) {
        client = clients.find(name => Bun.which(name + "-daemon"));
        if (!client) throw new Error("Wallpaper backend unavailable");
        const daemon = Bun.spawn([client + "-daemon"], {stdin: "ignore", stdout: "ignore", stderr: "ignore"});
        daemon.unref();
        let ready = false;
        for (let attempt = 0; attempt < 25; attempt++) {
            if (run([client, "query"], 300)) { ready = true; break; }
            await Bun.sleep(80);
        }
        if (!ready) {
            daemon.kill();
            throw new Error("Wallpaper backend did not start");
        }
    }

    if (!run([client, "img", "--resize", resize, "--", path])) throw new Error("Wallpaper update failed");
    return path;
}

if (import.meta.main) {
    try {
        const path = await applyWallpaper(Bun.argv[2] || "", Bun.argv[3] || "");
        console.log(JSON.stringify(path));
    } catch {
        process.exitCode = 1;
    }
}
