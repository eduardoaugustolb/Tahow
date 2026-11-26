# Tahow shell

Independent modular Quickshell shell and Ryostore subshell. The fork preserves DynamicIsland's JsonAdapter settings system and includes the Tahoe palette and companion qylock visual. Original UI glyphs are shipped as SVG source.

## Preferences

One file: `~/.config/tahow-shell/settings.json` (respects XDG_CONFIG_HOME). The legacy `~/.config/tahoe-shell/settings.json` is still read as a fallback while the canonical file does not exist yet; its values are copied into the canonical file on the first write. Top-level fields are General. Individual changes live in `overrides.island`, `overrides.palette`, `overrides.lockscreen`, and `overrides.input`. Settings pages edit these scopes; **Use General** clears that component's overrides. No component owns another preference file. Startup reads the canonical file before considering migration; a malformed or unreadable existing file is preserved. Preference edits are written atomically before returning, without a pending save timer. Write failures are logged and exposed through `Config.persistenceError`.

Example:

```json
{
  "appearance": "dark",
  "accentSource": "wallpaper",
  "motion": "balanced",
  "overrides": {
    "island": {"glassOpacity": 0.55, "bezel": 6, "thickness": 8, "ior": 1.2, "dispersion": 0.08},
    "palette": {"motion": "bouncy", "palettePosition": 0.28},
    "lockscreen": {"use24h": true}
  }
}
```

The settings window follows General dark/light appearance and the desktop accent. **Glass** has a live material preview, sliders and exact numeric inputs for opacity, accent tint, rim, frost, RGB dispersion, bevel, depth and refractive index. Choose General, Island, Spotlight or Lockscreen. **Use General** on this page removes only glass overrides and preserves unrelated component preferences. Lock field optics remain independently configurable. Theme color, motion and placement remain in their existing pages.

Open it directly with `qs -c shell ipc call tahoe settingsTab glass`. Live slider changes are coalesced before writing the shared preferences file.

## Boundaries

- Config: sole preferences writer and scope resolution.
- Theme: resolved island material, fonts, colors and motion. The palette resolves its own policy independently.
- Host: injected desktop port. Only adapters/Ryoku.qml imports Ryoku from the subshell. The companion launcher uses the host surface bus to open this one runtime without spawning a second process.
- DesktopTheme: watches Ryoku colors.json, theme.json and the named theme palette; subscribes to Ryogami wallpaper publications. Optional explicit hook: `qs -c shell ipc call tahoeTheme refresh`. It never writes Ryoku's color stores.
- Runtime: shared services and screen surfaces. Scene instantiates one runtime on the primary output. Start the standalone shell with `qs -n -d -p /path/to/Tahow/shell/shell.qml`. The running instance watches its files and reloads when they change.
- Desktop apps live under `apps/`. `Runtime.qml` and `PaletteRuntime.qml` both use `DesktopApps.qml` to open Files, Calendar and Terminal. Files uses the system folder handler. The installer prepares a separate Dolphin profile in `desktop-profile/` under Tahow's preferences, used when Dolphin is the default or no handler is configured. If the launch fails, Tahow opens its internal browser. Disable **Use the system file manager** in General to always use the internal browser.
- Terminal launches Kitty with the Tahow light or dark profile and uses the desktop accent for selection. Launching Kitty outside Tahow still uses your regular Kitty configuration.
- The Hyprland installer installs the WhiteSur theme under the user icon directory as `Tahow-WhiteSur` and activates it for Tahow's standalone launcher and Dolphin profile. The standalone shell picks up the theme on its next start and honors an existing `QS_ICON_THEME`.
- Host lock: separate companion theme, retaining qylock/PAM/fingerprint and suspend-inhibitor behavior. Standalone lock uses ext-session-lock/PAM and is never started in hosted mode.

## Rendering and lifecycle

Island pills, split bubbles, hover previews, banners and expanded states share a desktop snapshot acquired before the overlay's first presentation. The same texture survives size and content transitions: the visible island is never hidden or recaptured during a morph. The simulated material remains underneath until a liquid frame has been submitted, then blends into the prepared glass. With capture disabled or unavailable it keeps the fallback material. Workspace, OSD, device and notification pills do not request hover previews. Palette and settings captures hide only themselves; other Tahow components remain visible. The shared capture counter guards focus and hover handling and never controls another component's opacity. These are frozen desktop captures, never substituted wallpaper or live tracking of windows moving behind the glass. Reloading the shell acquires a fresh island snapshot.

Spotlight inherits General light, dark or automatic appearance and accepts overrides under `overrides.palette`. It uses compositor-live Liquid Glass when available, even with `screenCapture` disabled. With capture enabled it can fall back to a single frozen output snapshot acquired before the panel opens. Otherwise it uses simulated glass. Closing Spotlight releases its snapshot.

## Controls

Standard Ryoku launcher and lock actions select the companion products. IPC:

- `qs -c shell ipc call tahoe launcher` opens Spotlight
- `qs -c shell ipc call tahoe openApplications ""` opens the application grid on the active display
- `qs -c shell ipc call tahoe openApp files` opens Files (also `calendar` or `terminal`)
- `qs -c shell ipc call tahoe settings`
- `qs -c shell ipc call tahoe clipboard`
- `qs -c shell ipc call tahoe emojis`
- `qs -c shell ipc call tahoe settingsTab island` (also general, palette, lockscreen, system, shortcuts)
- `qs -c shell ipc call tahoeIsland toggle`
- `qs -c shell ipc call tahoeIsland center`

In **Appearance**, set **Icon style** to Default, Dark, Clear or Tinted for Spotlight and the application grid. Files and Calendar follow Tahow’s appearance and accent. Terminal opens Kitty with matching colors when installed, or uses the available system terminal. Kitty overrides apply only to the launched process.

Shortcuts reads all effective categories from `ryoku-hub keybinds` and supports search. Mouse/keyboard gestures and Tahoe IPC are shown separately. Removed Hyprland GlobalShortcut bindings are not advertised.

In Spotlight, **Ctrl + 1** opens Applications, **Ctrl + 2** opens Recent files, **Ctrl + 3** opens Actions, and **Ctrl + 4** opens Clipboard. Recent files come from the desktop's `recently-used.xbel` list. Clipboard results appear after you choose **Show history** in the Tahow input panel. Selecting one copies the item to the clipboard. Actions and Clipboard use the full Tahow shell runtime.

Spotlight search ranks apps, recent files and actions by name and available metadata. Type arithmetic such as `(12 + 8) / 4` for a live result. Press Enter to copy it via `wl-copy`. Type a URL to open it, select **Search the web** under the local results, or prefix a query with `?` to search DuckDuckGo directly. The default browser opens only when you select a web result.

The standalone Hyprland installer creates **Super + E** for Files, **Super + V** for Clipboard and **Super + .** for Emojis on install and update when those combinations are free in the Tahow shortcut file. Clipboard and Emojis share a panel with a keyboard tab for Brazilian Portuguese letters and accents. For manual bindings, use `sh ~/.config/tahow-shell/bin/shortcut-ipc.sh` with `files`, `clipboard` or `emojis`.

Typing, emoji insertion and the current clipboard’s paste button use `wtype` and require a compositor with Wayland virtual keyboard support. After you choose **Show history**, Tahow reads existing `cliphist` entries and records copied images until the shell closes. Image previews use ImageMagick. Clicking a history item restores it to the Wayland clipboard using `wl-copy` from `wl-clipboard`.

The panel uses its own material and appearance preferences under **Input panel**, with General as the default. It uses the native Hyprland glass plugin when available. With screen capture enabled and no compatible plugin, it takes a single pre-opening snapshot. Otherwise it uses the simulated material. The emoji tab uses Keymoji's catalog, Portuguese and English search, and a session-only Recent category. It prefers the locally available Apple Color Emoji font and otherwise uses the system emoji font.

Standalone lock: `qs -p /path/to/Tahow/shell/shell.qml ipc call tahoeLock lock`. Configure pamService for the distribution. No system PAM policy is installed by this product. Real password authentication must be checked by the user; automated validation does not request passwords or unlock a real session.

## Install / validation

Install barstyles/tahoe-shell, launchers/tahoe-shell and lockscreens/tahoe-shell through Ryostore, then select `ryoku-shell barstyle tahoe-shell`, the Tahoe Shell Palette in Hub > App Launcher, and `ryoku-hub lock set tahoe-shell`.

From the repository root, run `bun run check` and `bun test`. Edit the shared Qt glass profile in `shaders/frosted_glass.frag` and run `bun tools/build-shaders.ts` to rebuild the shaders, synchronize the standalone copies, and regenerate the widget packages. The native provider in `../native/live-glass` renders the corresponding profile inside Hyprland. Synchronize translation outputs with `bun tools/sync-i18n.ts`. Export the companions with `bun tools/export-ryostore.ts --to /path/to/ryostore` and inspect the target diff before publishing.

Runtime behavior has been tested on Hyprland. niri is not yet validated. Automated lock checks use simulated authentication; actual lock/unlock remains a manual target-machine check. The root [README](../README.md) describes the supported development workflow.

## Maintenance / permissions

Combined distribution: AGPL-3.0, with DynamicIsland's MIT and the earlier Tahoe palette's GPL notices retained under THIRD_PARTY_LICENSES. See [NOTICE.md](../NOTICE.md). Icon geometry is original, not copied from Apple or Icons8. Upstream services include PipeWire, UPower, Bluetooth, NetworkManager/nmcli, brightnessctl, weather/location network requests and audio cues. Weather and location are configurable. No competing notification daemon is killed; the Ryoku adapter shares the host server. Maintained by the contributor.

**Wallpaper** previews local images, applies fill or fit to all outputs through awww/swww, and restores the selected wallpaper when standalone Tahow starts. Login wallpaper remains under **Lock Screen**. The wallpaper backend starts on demand.
