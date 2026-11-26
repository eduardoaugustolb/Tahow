const [, , entry, imageFormat] = Bun.argv;
if (!entry || !/^\d+$/.test(entry)) process.exit(2);
if (imageFormat && !/^(png|jpeg|jpg|gif|webp|bmp|tiff)$/.test(imageFormat)) process.exit(2);

const decoded = Bun.spawnSync(["cliphist", "decode", entry], { stderr: "ignore" });
if (!decoded.success) process.exit(1);

if (imageFormat) {
    const thumbnail = Bun.spawnSync([
        "magick", "-limit", "memory", "64MiB", "-limit", "map", "128MiB",
        "-limit", "disk", "0", "-limit", "time", "5", `${imageFormat}:-[0]`,
        "-thumbnail", "152x108", "-strip", "png:-"
    ], { stdin: decoded.stdout, stderr: "ignore" });
    if (!thumbnail.success) process.exit(1);
    process.stdout.write("data:image/png;base64," + thumbnail.stdout.toString("base64"));
    process.exit(0);
}

const copy = Bun.spawnSync(["wl-copy"], { stdin: decoded.stdout, stdout: "ignore", stderr: "ignore" });
process.exit(copy.exitCode);
