# Liquid glass on island pills

The user requested refractive glass on compact notification, media and other
pills, with no hide/capture/show blink. This supersedes the previous simulated-only
compact-island policy documented in AGENTS.md and the earlier hover verification.

IslandWindow acquires one clean output snapshot before presenting its island,
banners or center. The Ryoku adapter waits for the reload-cover process to leave
before allowing that capture. That probe stops after startup; a probe error
selects fallback instead of capturing a possibly covered output. Capture failure
has a 700 ms fallback deadline. Compact, preview, split and expanded surfaces
reuse the prepared texture, including during size/content transitions. They never
capture the previous pill into its replacement or fade the island away to capture.

Glass keeps its fallback under the liquid surface and blends the material over
150 ms (1 ms with reduced motion) after an actual submitted frame. In this Qt/RHI
runtime, QSB shader status remained Uncompiled despite rendering with a seeded
pipeline cache, so Compiled alone was not a usable presentation fence. Source
geometry continues to update with the spring animations. No shader source or
compiled QSB artifact changed.

The island snapshot is frozen for the lifetime of the window. It does not follow
window movements or background changes; shell reload obtains a fresh snapshot.
Capture-disabled/unavailable surfaces retain the fallback. Palette and Settings
keep their separate capture behavior. No wallpaper is substituted for the desktop.

## Verification

Environment: live Ryoku Hyprland, Bun 1.4.4, Qt Quick OpenGL on AMD Radeon
Graphics/Mesa. niri was not tested.

- `bun run check`: passed (133 QML files and current generated catalogues).
- `bun test`: 51 passed, 0 failed.
- `bun tools/verify-pill-glass.ts --wayland`: 14 states, 420 sampled frames,
  with normal motion; liquid material ready throughout, island and overlay
  opacity 1, captureCount 0, and the same texture throughout all morphs.
- `bun tools/verify-pill-glass.ts`: 14 states, 420 sampled frames with capture
  disabled; fallback remained available with no capture ownership or opacity drop.
- The real-capture sequence also passed with reduced motion before the normal
  motion run. Inspected captured idle preview, media preview and notification
  pill images in `/tmp/tahow-pill-*.png`.
- Offscreen execution was attempted but PanelWindow has no offscreen backend;
  both successful tests ran on Wayland with isolated preferences, fake
  notifications and no Runtime/Lockscreen/authentication instance.

## Installation

Exported to the existing local Ryostore catalogue, reviewed its diff, refreshed
its cache and installed only `barstyles/tahoe-shell` using Ryostore. The catalogue
already had unrelated uncommitted changes; nothing was published or pushed.
Reloaded with `ryoku reload`. Installed Glass.qml and Notifs.qml hashes match
repository sources. The canonical preferences hash stayed unchanged:
`82fd462820d3cf5c28115e25b6d97cb0f8dc7642f250d2b1a27f5c1cff63cd8a`.

Installed IPC reported idle, liquidReady true, liquidMix 1, presentationReady
true, captureHasContent true, island/overlay opacity 1 and captureCount 0.
`bun tools/verify-glass.ts ~/.config/quickshell/shell/shell.qml` then passed two
palette/island open-close cycles with capture ownership released. No real
passwords, authentication, lock or unlock were automated.
