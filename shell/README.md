# Tahow shell

Independent modular Quickshell shell and Ryostore subshell. The fork preserves DynamicIsland's JsonAdapter settings system and includes the Tahoe palette and companion qylock visual. Original UI glyphs are shipped as SVG source.

## Preferences

One file: `~/.config/tahow-shell/settings.json` (respects XDG_CONFIG_HOME). The legacy `~/.config/tahoe-shell/settings.json` is still read as a fallback while the canonical file does not exist yet; its values are copied into the canonical file on the first write. Top-level fields are General. Individual changes live in `overrides.island`, `overrides.palette`, and `overrides.lockscreen`. Settings tabs edit these scopes; **Use General** clears that component's overrides. No component owns another preference file. Startup reads the canonical file before considering migration; a malformed or unreadable existing file is preserved. Preference edits are written atomically before returning, without a pending save timer. Write failures are logged and exposed through `Config.persistenceError`.

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

The settings window follows General dark/light appearance and the desktop accent. **Glass** has a live material preview, sliders and exact numeric inputs for opacity, accent tint, rim, frost, RGB dispersion, bevel, depth and refractive index. Choose General, Island, Command Palette or Lockscreen. **Use General** on this page removes only glass overrides and preserves unrelated component preferences. Lock field optics remain independently configurable. Theme color, motion and placement remain in their existing pages.

Open it directly with `qs -c shell ipc call tahoe settingsTab glass`. Live slider changes are coalesced before writing the shared preferences file.

## Boundaries

- Config: sole preferences writer and scope resolution.
- Theme: resolved island material, fonts, colors and motion. The palette resolves its own policy independently.
- Host: injected desktop port. Only adapters/Ryoku.qml imports Ryoku from the subshell. The companion launcher uses the host surface bus to open this one runtime without spawning a second process.
- DesktopTheme: watches Ryoku colors.json, theme.json and the named theme palette; subscribes to Ryogami wallpaper publications. Optional explicit hook: `qs -c shell ipc call tahoeTheme refresh`. It never writes Ryoku's color stores.
- Runtime: shared services and screen surfaces. Scene instantiates one runtime on the primary output. Standalone entry: `qs -p /path/to/Tahow/shell/shell.qml`.
- Host lock: separate companion theme, retaining qylock/PAM/fingerprint and suspend-inhibitor behavior. Standalone lock uses ext-session-lock/PAM and is never started in hosted mode.

## Rendering and lifecycle

Island pills, split bubbles, hover previews, banners and expanded states share a desktop snapshot acquired before the overlay's first presentation. The same texture survives size and content transitions: the visible island is never hidden or recaptured during a morph. The simulated material remains underneath until a liquid frame has been submitted, then blends into the prepared glass. With capture disabled or unavailable it keeps the fallback material. Workspace, OSD, device and notification pills do not request hover previews. Palette and settings captures hide only themselves; other Tahow components remain visible. The shared capture counter guards focus and hover handling and never controls another component's opacity. These are frozen desktop captures, never substituted wallpaper or live tracking of windows moving behind the glass. Reloading the shell acquires a fresh island snapshot.

The palette appears immediately with a stable surface. Its frozen output texture uses fixed coordinates while the foreground bubble animates, avoiding crop-texture rebuilds. Bouncy uses the configured spring/damping. Captures are released when the palette closes. Screen capture requires provider support; disable screenCapture for an opaque palette fallback.

## Controls

Standard Ryoku launcher and lock actions select the companion products. IPC:

- `qs -c shell ipc call tahoe launcher`
- `qs -c shell ipc call tahoe settings`
- `qs -c shell ipc call tahoe settingsTab island` (also general, palette, lockscreen, system, shortcuts)
- `qs -c shell ipc call tahoeIsland toggle`
- `qs -c shell ipc call tahoeIsland center`

Shortcuts reads all effective categories from `ryoku-hub keybinds` and supports search. Mouse/keyboard gestures and Tahoe IPC are shown separately. Removed Hyprland GlobalShortcut bindings are not advertised.

Standalone lock: `qs -p /path/to/Tahow/shell/shell.qml ipc call tahoeLock lock`. Configure pamService for the distribution. No system PAM policy is installed by this product. Real password authentication must be checked by the user; automated validation does not request passwords or unlock a real session.

## Install / validation

Install barstyles/tahoe-shell, launchers/tahoe-shell and lockscreens/tahoe-shell through Ryostore, then select `ryoku-shell barstyle tahoe-shell`, the Tahoe Shell Palette in Hub > App Launcher, and `ryoku-hub lock set tahoe-shell`.

From the repository root, run `bun run check` and `bun test`. Rebuild shaders with `bun tools/build-shaders.ts`; synchronize translation outputs with `bun tools/sync-i18n.ts`. Export the companions with `bun tools/export-ryostore.ts --to /path/to/ryostore` and inspect the target diff before publishing.

Runtime behavior has been tested on Hyprland. niri is not yet validated. Automated lock checks use simulated authentication; actual lock/unlock remains a manual target-machine check. The root [README](../README.md) describes the supported development workflow.

## Maintenance / permissions

Combined distribution: AGPL-3.0, with DynamicIsland's MIT and the earlier Tahoe palette's GPL notices retained under THIRD_PARTY_LICENSES. See [NOTICE.md](../NOTICE.md). Icon geometry is original, not copied from Apple or Icons8. Upstream services include PipeWire, UPower, Bluetooth, NetworkManager/nmcli, brightnessctl, weather/location network requests and audio cues. Weather and location are configurable. No competing notification daemon is killed; the Ryoku adapter shares the host server. Maintained by the contributor.
