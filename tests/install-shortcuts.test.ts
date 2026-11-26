import { expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("the launcher shortcut starts Quickshell once and waits for its IPC", () => {
    const temp = mkdtempSync(join(tmpdir(), "tahow-launcher-"));
    try {
        const result = Bun.spawnSync(["bash", "-euo", "pipefail", "-c", String.raw`
            export PATH="$1/bin:$PATH" TAHOW_TEST="$1"
            mkdir -p "$1/bin"
            cat > "$1/bin/qs" <<'MOCK'
#!/bin/sh
set -eu
case "$1" in
    -n)
        test "$*" = "-n -d -p $TAHOW_TEST/shell.qml"
        test ! -e "$TAHOW_TEST/started"
        touch "$TAHOW_TEST/started"
        ;;
    -p)
        test "$*" = "-p $TAHOW_TEST/shell.qml ipc call tahoe launcher"
        test -e "$TAHOW_TEST/started" || exit 1
        if [ ! -e "$TAHOW_TEST/ready" ]; then
            touch "$TAHOW_TEST/ready"
            printf '%s\n' 'Not ready to accept queries yet.'
            exit 0
        fi
        printf 'launcher\n' >> "$TAHOW_TEST/calls"
        ;;
esac
MOCK
            chmod +x "$1/bin/qs"
            cp shell/bin/shortcut-ipc.sh "$1/bin/"
            sh "$1/bin/shortcut-ipc.sh" launcher
            sh "$1/bin/shortcut-ipc.sh" launcher
            test "$(wc -l < "$1/calls")" -eq 2
        `, "tahow-test", temp]);
        expect(result.stderr.toString()).toBe("");
        expect(result.exitCode).toBe(0);
    } finally {
        rmSync(temp, { recursive: true, force: true });
    }
});

for (const format of ["conf", "lua"]) {
    test(`Hyprland ${format} shortcuts are installed once and survive removal`, () => {
        const temp = mkdtempSync(join(tmpdir(), "tahow-shortcuts-"));
        try {
            const result = Bun.spawnSync(["bash", "-euo", "pipefail", "-c", String.raw`
                HYPR_DIR="$1/config space/hypr"
                TAHOW_CONFIG_DIR="$1/config space/tahow-shell"
                MODE=install
                DIM= RESET= SUCCESS= BOLD= GRAY=
                step() { :; }
                success_item() { :; }
                print_banner() { :; }
                qs() { :; }
                hyprctl() { return 1; }
                mkdir -p "$HYPR_DIR"
                entry="$HYPR_DIR/hyprland.$2"
                shortcuts="$HYPR_DIR/tahow/shortcuts.$2"
                window_shortcuts="$HYPR_DIR/tahow/window-shortcuts.$2"
                workspace_shortcuts="$HYPR_DIR/tahow/workspace-shortcuts.$2"
                touch "$entry"
                source <(sed -n \
                    -e '/^start_tahow_shell() {$/,/^}$/p' \
                    -e '/^configure_ryoku_autostart() {$/,/^}$/p' \
                    -e '/^configure_hyprland() {$/,/^print_summary() {$/ { /^print_summary() {$/!p; }' \
                    -e '/^uninstall_tahow() {$/,/^}$/p' install.sh)

                configure_hyprland
                case "$2" in
                    lua)
                        grep -Fq 'bindLauncher("SUPER + Space", hl.dsp.exec_cmd(ipc .. "launcher"), { description = "Spotlight" })' "$shortcuts"
                        grep -Fq 'hl.unbind(key)' "$shortcuts"
                        grep -Fq 'hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd(ipc .. "settings"), { description = "Open preferences" })' "$shortcuts"
                        grep -Fq 'hl.bind("SUPER + V", hl.dsp.exec_cmd(ipc .. "clipboard")' "$shortcuts"
                        grep -Fq 'hl.bind("SUPER + period", hl.dsp.exec_cmd(ipc .. "emojis")' "$shortcuts"
                        grep -Fq "local ipc = \"sh '\" .. shell:gsub(\"/shell%.qml\$\", \"/bin/shortcut-ipc.sh\") .. \"' \"" "$shortcuts"
                        grep -Fxq 'require("tahow.shortcuts")' "$HYPR_DIR/tahow/init.lua"
                        grep -Fxq 'require("tahow.window-shortcuts")' "$HYPR_DIR/tahow/init.lua"
                        grep -Fq 'hl.bind("ALT + Tab"' "$window_shortcuts"
                        test "$(grep -c '^hl.bind(' "$window_shortcuts")" -eq 6
                        grep -Fxq 'require("tahow.workspace-shortcuts")' "$HYPR_DIR/tahow/init.lua"
                        grep -Fq 'for workspace = 1, 10 do' "$workspace_shortcuts"
                        grep -Fq 'description = "Go to workspace " .. workspace' "$workspace_shortcuts"
                        grep -Fxq 'hl.unbind("Print")' "$shortcuts"
                        test "$(grep -Fc 'hl.bind("Print", hl.dsp.exec_cmd(ipc .. "capture")' "$shortcuts")" -eq 1
                        grep -Fq 'hl.bind("SUPER + SHIFT + code:" .. (9 + workspace), hl.dsp.window.move({ workspace = tostring(workspace), follow = true })' "$workspace_shortcuts"
                        grep -F -B2 'hl.bind("SUPER + SHIFT + code:"' "$workspace_shortcuts" | grep -Fq 'hl.unbind("SUPER + SHIFT + code:" .. (9 + workspace))'
                        cat > "$shortcuts" <<'LEGACY'
local ipc = "sh " .. shell:gsub("/shell%.qml$", "/bin/shortcut-ipc.sh") .. " "
hl.bind("ALT + Space", hl.dsp.exec_cmd(ipc .. "launcher"), { description = "Spotlight" })
LEGACY
                        configure_hyprland
                        grep -Fq 'bindLauncher("ALT + Space",' "$shortcuts"
                        grep -Fq "local ipc = \"sh '\" .. shell:gsub(\"/shell%.qml\$\", \"/bin/shortcut-ipc.sh\") .. \"' \"" "$shortcuts"
                        cp "$shortcuts" "$1/migrated"
                        configure_hyprland
                        cmp "$shortcuts" "$1/migrated"
                        ;;
                    conf)
                        grep -Fxq "bindd = SUPER, Space, Spotlight, exec, sh '$TAHOW_CONFIG_DIR/bin/shortcut-ipc.sh' launcher" "$shortcuts"
                        grep -Fxq "bindd = SUPER SHIFT, Space, Open preferences, exec, sh '$TAHOW_CONFIG_DIR/bin/shortcut-ipc.sh' settings" "$shortcuts"
                        grep -Fxq "bindd = SUPER, V, Clipboard, exec, sh '$TAHOW_CONFIG_DIR/bin/shortcut-ipc.sh' clipboard" "$shortcuts"
                        grep -Fxq "bindd = SUPER, period, Emojis, exec, sh '$TAHOW_CONFIG_DIR/bin/shortcut-ipc.sh' emojis" "$shortcuts"
                        grep -Fxq "source = $shortcuts" "$HYPR_DIR/tahow/tahow.conf"
                        grep -Fxq "exec-once = sh '$TAHOW_CONFIG_DIR/bin/start-shell.sh'" "$HYPR_DIR/tahow/tahow.conf"
                        grep -Fxq "source = $window_shortcuts" "$HYPR_DIR/tahow/tahow.conf"
                        grep -Fxq 'bindd = ALT, Tab, Switch windows, cyclenext,' "$window_shortcuts"
                        test "$(grep -c '^bindd\? =' "$window_shortcuts")" -eq 7
                        grep -Fxq "source = $workspace_shortcuts" "$HYPR_DIR/tahow/tahow.conf"
                        test "$(grep -Fxc "bindd = , Print, Screenshot, exec, sh '$TAHOW_CONFIG_DIR/bin/shortcut-ipc.sh' capture" "$shortcuts")" -eq 1
                        for workspace in {1..10}; do
                            grep -Fxq "bindd = SUPER, $((workspace % 10)), Go to workspace $workspace, workspace, $workspace" "$workspace_shortcuts"
                            grep -Fxq "bindd = SUPER SHIFT, code:$((9 + workspace)), Move window to workspace $workspace, movetoworkspace, $workspace" "$workspace_shortcuts"
                            grep -Fxq "unbind = SUPER SHIFT, code:$((9 + workspace))" "$workspace_shortcuts"
                        done
                        ;;
                esac

                # Reinstall over a pre-panel config with a personalized shortcut.
                case "$2" in
                    lua)
                        sed -i '/ipc \.\. "clipboard"/d; /ipc \.\. "emojis"/d' "$shortcuts"
                        printf '%s\n' 'hl.bind("Super+V", hl.dsp.exec_cmd("custom-action"))' >> "$shortcuts"
                        ;;
                    conf)
                        sed -i '/shortcut-ipc\.sh.* clipboard$/d; /shortcut-ipc\.sh.* emojis$/d' "$shortcuts"
                        printf '%s\n' 'bind = SUPER, v, exec, custom-action' >> "$shortcuts"
                        ;;
                esac
                configure_hyprland
                grep -Fq 'custom-action' "$shortcuts"
                test "$(grep -c 'emojis' "$shortcuts")" -eq 1
                if grep -q 'clipboard' "$shortcuts"; then exit 1; fi
                sed -i '/custom-action/d' "$shortcuts"
                configure_hyprland
                test "$(grep -c 'clipboard' "$shortcuts")" -eq 1
                cp "$shortcuts" "$1/updated-shortcuts"
                configure_hyprland
                cmp "$shortcuts" "$1/updated-shortcuts"

                : > "$shortcuts"
                : > "$window_shortcuts"
                : > "$workspace_shortcuts"
                cp "$entry" "$1/entry"
                configure_hyprland
                cmp "$entry" "$1/entry"
                test ! -s "$shortcuts"
                test ! -s "$window_shortcuts"
                test ! -s "$workspace_shortcuts"
                hyprctl() { test "$*" = reload; }
                qs() {
                    test "$#" -eq 4
                    test "$1 $2 $3" = "-n -d -p"
                    test "$4" = "$TAHOW_CONFIG_DIR/shell.qml"
                    activated="$MODE"
                }
                configure_hyprland
                test "$activated" = install
                MODE=update
                configure_hyprland
                test "$activated" = update
                qs() { :; }
                (uninstall_tahow)
                test -f "$shortcuts"
                test -f "$window_shortcuts"
                test -f "$workspace_shortcuts"
                test -z "$(cat "$entry")"
            `, "tahow-test", temp, format]);
            expect(result.stderr.toString()).toBe("");
            expect(result.exitCode).toBe(0);
        } finally {
            rmSync(temp, { recursive: true, force: true });
        }
    });
}

test("installing live glass replaces the file before reloading the active plugin", () => {
    const temp = mkdtempSync(join(tmpdir(), "tahow-plugin-"));
    try {
        const result = Bun.spawnSync(["bash", "-euo", "pipefail", "-c", String.raw`
            CONFIG_DIR="$1"
            TAHOW_SRC="$1/src"
            TAHOW_CONFIG_DIR="$1/tahow-shell"
            LOG_FILE="$1/install.log"
            DIM= RESET=
            step() { :; }
            success_item() { :; }
            run_with_spinner() { shift; "$@"; }
            bun() { printf 'new plugin' > "$TAHOW_SRC/native/live-glass/build/tahow-live-glass.so"; }
            mkdir -p "$TAHOW_CONFIG_DIR/native" "$TAHOW_SRC/native/live-glass/build"
            touch "$TAHOW_SRC/native/live-glass/build.ts"
            plugin="$TAHOW_CONFIG_DIR/native/live-glass.so"
            printf 'old plugin' > "$plugin"
            exec 3< "$plugin"
            hyprctl() {
                case "$*" in
                    "monitors -j") ;;
                    "plugin unload $plugin")
                        test "$(cat <&3)" = 'old plugin'
                        touch "$CONFIG_DIR/unloaded" ;;
                    "plugin load $plugin")
                        test -f "$CONFIG_DIR/unloaded"
                        test "$(cat "$plugin")" = 'new plugin'
                        touch "$CONFIG_DIR/loaded"
                        printf 'ok\n' ;;
                    *) return 1 ;;
                esac
            }
            source <(sed -n '/^build_and_deploy_assets() {$/,/^configure_hyprland() {$/ { /^configure_hyprland() {$/!p; }' install.sh)
            build_and_deploy_assets
            test -f "$CONFIG_DIR/loaded"
            test "$(cat "$plugin")" = 'new plugin'
        `, "tahow-test", temp]);
        expect(result.stderr.toString()).toBe("");
        expect(result.exitCode).toBe(0);
    } finally {
        rmSync(temp, { recursive: true, force: true });
    }
});
