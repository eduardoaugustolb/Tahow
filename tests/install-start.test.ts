import { expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("start-shell starts the shell detached once and reuses a running instance", () => {
    const temp = mkdtempSync(join(tmpdir(), "tahow-start-"));
    try {
        const result = Bun.spawnSync(["bash", "-euo", "pipefail", "-c", String.raw`
            export PATH="$1/bin:$PATH" TAHOW_TEST="$1"
            mkdir -p "$1/bin" "$1/tahow-shell/bin"
            cp shell/bin/start-shell.sh "$1/tahow-shell/bin/"

            cat > "$1/bin/qs" <<'MOCK'
#!/bin/sh
set -eu
case "$1" in
    list)
        test "$2" = "-p"
        test -e "$TAHOW_TEST/running"
        ;;
    --help)
        printf '%s\n' '  -d, --daemonize  Detach from the controlling terminal.'
        ;;
    -n)
        printf '%s\n' "$*" >> "$TAHOW_TEST/spawns"
        test "$*" = "-n -d -p $TAHOW_TEST/tahow-shell/shell.qml"
        touch "$TAHOW_TEST/running"
        ;;
esac
MOCK
            chmod +x "$1/bin/qs"

            sh "$1/tahow-shell/bin/start-shell.sh"
            sh "$1/tahow-shell/bin/start-shell.sh"

            test "$(wc -l < "$1/spawns")" -eq 1
            test "$(cat "$1/spawns")" = "-n -d -p $1/tahow-shell/shell.qml"
        `, "tahow-test", temp]);
        expect(result.stderr.toString()).toBe("");
        expect(result.exitCode).toBe(0);
    } finally {
        rmSync(temp, { recursive: true, force: true });
    }
});

test("Ryoku autostart keeps one detached launcher inside the start handler", () => {
    const temp = mkdtempSync(join(tmpdir(), "tahow-autostart-"));
    try {
        const result = Bun.spawnSync(["bash", "-euo", "pipefail", "-c", String.raw`
            HYPR_DIR="$1/config space/hypr"
            TAHOW_CONFIG_DIR="$1/config space/tahow-shell"
            BOLD= DIM= RESET= SUCCESS= GRAY=
            success_item() { :; }
            mkdir -p "$HYPR_DIR/config"

            cat > "$HYPR_DIR/config/autostart.lua" <<'LUA'
-- Auto-start config
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("sh -c 'pgrep -f tahow-shell/shell.qml >/dev/null || qs -p ~/.config/tahow-shell/shell.qml >/dev/null 2>&1 &'")
    hl.exec_cmd("xhost +SI:localuser:root")
end)
LUA

            source <(sed -n '/^configure_ryoku_autostart() {$/,/^}$/p' install.sh)
            configure_ryoku_autostart

            file="$HYPR_DIR/config/autostart.lua"
            test "$(grep -c 'tahow-shell/bin/start-shell.sh' "$file")" -eq 1
            grep -Fq "hl.exec_cmd(\"sh '$TAHOW_CONFIG_DIR/bin/start-shell.sh'\")" "$file"
            test -z "$(grep -F 'pgrep -f tahow-shell' "$file")"
            grep -Fq 'hl.exec_cmd("xhost +SI:localuser:root")' "$file"
            grep -A1 'hl\.on("hyprland\.start"' "$file" | grep -Fq 'start-shell.sh'

            cp "$file" "$1/first"
            configure_ryoku_autostart
            cmp "$file" "$1/first"
        `, "tahow-test", temp]);
        expect(result.stderr.toString()).toBe("");
        expect(result.exitCode).toBe(0);
    } finally {
        rmSync(temp, { recursive: true, force: true });
    }
});
