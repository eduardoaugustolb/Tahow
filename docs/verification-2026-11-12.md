# Capture and integration verification — 2026-11-12

Environment: Ryoku on live Hyprland (`ryoku wm status`); source runtime started
with `qs -p shell/shell.qml`. After source validation, the three companions were
exported to the configured local Ryostore checkout, installed with `ryostore
install`, and activated with `ryoku-shell reload`. Installed files were not
hand-patched. niri was not tested. Authentication was not exercised.

## Capture regression

Before the fix, palette IPC reported `captureHasContent: true`,
`frameReady: false`, and `captureFailed: true`. The expanded island had no
backdrop. Both waited for `ShaderEffectSource.scheduleUpdate()` completion
while the consumer was hidden, preventing the texture from rendering.

The capture source now holds a single frame (`ScreencopyView.live: false`).
Presentation starts when that frame arrives; the texture provider can upload
it when the visible shader renders. The provider's `live: true` does not
request further compositor captures. Island windows also hide during another
owned capture; their own acquisition uses the existing fade before capture.

`bun tools/verify-glass.ts` passed two palette/island open-close cycles with
ready textures and released capture ownership. The script requires an already
running source runtime with glass and screen capture enabled. It never opens
the lockscreen or reads authentication input. Desktop screenshots were inspected
at `/tmp/tahow-palette-verified.png` and `/tmp/tahow-island-verified.png`.
The same two-cycle check passed against the installed shell after reload.

## Material and RGB dispersion

Palette, island and lock field share the generated material color policy.
The palette's former fixed beige/grey tint and private opacity multipliers
were removed. Lock field intensity remains independently controlled by
`lockTint`.

At the user's request, chromatic dispersion was increased to `0.08` in all
three components. The `tahoe.setDispersion` IPC action persists all three scope
overrides in one adapter write, preserving unrelated settings. The saved
island, palette and lockscreen values were read back as `0.08`. Final checks:
`bun run check`, 28 passing tests, and the installed Hyprland capture cycle.

## Notification alignment

The notification pill's minimum height exceeded its content height, but its
content stayed at a fixed top offset. Centering that content and the title/time
header fixes title-only notifications as well as body variants. Three variants
were inspected in `/tmp/tahow-notification-alignment.png`. The offscreen render
did not validate icon rendering on Wayland.

## Distribution boundary

The exporter retires the legacy launcher listing while preserving its files
for existing receipts. Tests verify preflight, manifest hashes, unrelated
entries, and repeated export. A review catalogue lives in
`/tmp/tahow-catalogue-review`.

The installed Hub filters Subshells with a fixed allowlist, independently of
catalogue tags. The integration contract and compatibility evidence live in
`integrations/ryoku/`. Work on host packaging was stopped at the user's
direction; no host source patch or speculative configuration identifier is
shipped. The launcher declares only supported capabilities, and the own Glass
page has the stable IPC route `tahoe settingsTab glass`.

## Glass settings section

The dedicated Glass page provides General/Island/Palette/Lockscreen scope
selection, a local procedural material preview, sliders, exact numeric inputs
and a partial inheritance reset. Optical General values are now persisted by
both canonical and legacy adapters instead of being replaced by hardcodes.
Palette optics consume these effective preferences. Rapid slider updates are
coalesced into one write to prevent stale reloads from replacing newer edits.

`bun tools/verify-glass-settings.ts` passed against an isolated temporary store
using the actual QML controls: slider movement, exact input, scope inheritance,
partial reset and saved-file readback. No user preferences or authentication
are used by that test. The real dark-mode page was visually inspected on
Hyprland at `/tmp/tahow-glass-settings.png`; light mode and niri were not
visually validated in this run. `bun run check` and all 30 tests passed.
The catalogue was exported and all three companions installed through
Ryostore, then the shell reloaded. The installed capture regression passed
again, and the Glass page was opened for the user.
