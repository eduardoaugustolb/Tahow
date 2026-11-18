# Backdrop memory budget and live-capture boundary

> Historical report: the live-provider limitation described below is superseded by the [2026-11-18 compositor integration](verification-2026-11-18-compositor-glass.md). The texture budget remains relevant to the snapshot fallback.

## Requested behavior

Refract the actual scene behind each surface, including moving windows and
video. A wallpaper texture is not an implementation of that requirement.

## Change

IslandWindow, Sheet and SettingsWindow request intermediate backing textures
with at most 2,073,600 pixels and a maximum dimension of 2048. Coordinates remain
in logical screen space. The original ScreencopyView buffer is not reduced by
this change. Mipmaps remain required by the existing shader's textureLod blur.
On an unscaled 4K output, the intermediate RGBA8 texture plus mipmaps goes from
approximately 42.2 MiB to 10.5 MiB. This is an allocation calculation, not a
measurement of total process memory or GPU time. High-resolution detail is
reduced on outputs exceeding the budget; 1920x1080 remains unchanged.

An initially explored direct-wallpaper sampler for widgets was withdrawn after
the user clarified that the actual scene behind elements is required. Existing
widget sources and generated products retain their previous material behavior.
This change does not implement live glass.

## Capture boundary

The island currently acquires a clean output snapshot before its first
presentation, then retains that snapshot. The palette and settings have their
own acquisition lifecycle. Widgets currently use wallpaper. Simply switching
output screencopy to live captures the shell itself, causing feedback.

Quickshell ScreencopyView accepts output and toplevel capture sources, but does
not expose an exclude-shell-layers option. A toplevel feed alone cannot reproduce
the composited scene (stacked windows, backgrounds, other layers). Hyprland's
no_screen_share rule is screen-sharing redaction, not an underlay texture API.

A faithful live implementation needs compositor support: obtain the composed
scene below the requesting surface before drawing that surface; export a bounded
GPU buffer; import it as a texture; update from damage/frame events; keep a small
fixed number of buffers. Keep this in the Hyprland adapter rather than introducing
a desktop-specific dependency in shell/shell.qml. Verify capabilities before
selecting the live provider. Preserve the snapshot fallback with accurate status.
No new provider, protocol, compositor plugin or desktop configuration was installed.

References:
- https://master.quickshell.org/docs/types/Quickshell.Wayland/ScreencopyView
- https://wiki.hypr.land/configuring/core/rules/layer-rules/
- https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html#textureSize-prop

## Verification

Hyprland on AMD Ryzen 5 5625U / Barcelo integrated Radeon; built-in screen
1920x1080 scale 1. No niri validation or 4K allocation benchmark.

- bun run check: QML syntax and generated translations passed.
- bun test: passed, including texture-budget tests.
- bun tools/verify-pill-glass.ts --wayland: 14 modes, 420 samples passed.
- bun tools/verify-pill-glass.ts: capture-disabled fallback, 14 modes, 420 samples passed.
- A temporary Wayland test with a synthetic RGB image confirmed the explored
  direct Image sampler renders and matches centered cover placement; the offscreen
  backend returned a black image and was not treated as visual evidence. The
  sampler change was subsequently withdrawn as outside the clarified goal.

Existing user changes in TrayStrip, widget faces/manifests and tray verification
fixtures were retained. No publication or installed-shell reload was performed.
