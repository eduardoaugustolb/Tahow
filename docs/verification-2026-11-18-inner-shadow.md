# Inner shadow and Preferences surface coordinates — 2026-11-18

The glass page now exposes **Inner shadow / Sombra interna** (0–1) for General,
Island and Command Palette. Zero removes only optical edge darkening; one keeps
the previous intensity. Component overrides inherit and reset through the existing
preferences model. Independent widgets expose the same setting in their own
material preferences. The lockscreen's separate shader and authentication are
unchanged.

The native provider compiles private variants of the running compositor's acrylic
finish shader, multiplying only its shadow term by a per-region uniform. Source
comes from the matching installed Hyprland shader loader; no compositor files or
global shader-cache entries are patched. The variant hook is scoped to Tahow's
material draw and is removed during unload. Snapshot glass and the settings preview
apply the same parameter to the QSB shader's two edge-darkening terms. Shader
artifacts and widget packages are regenerated with their normal generators.

Preferences now sends geometry and clipping relative to its own surface.
Wayland clients cannot supply reliable global toplevel coordinates. The provider
maps these local bounds through the authenticated window's actual render pass;
damage notifications resolve the owning window by PID and title. This fixes the
apparent second window at output origin: it was a detached sidebar material.

## Verification

Environment: Hyprland 0.57.2, commit
`11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947`, OpenGL, AMD Barcelo,
isolated compositor with 1280×960 headless output at scale 1. The compositor
initially inherited an inactive TTY and refused normal rendering, including with
the original plugin. A test-only helper restricted to that compositor's exact
instance ID activated its render fixture; no primary-session activation or input
was simulated. The helper is outside the repository and is not shipped.

- `bun tools/verify-glass-settings.ts`: zero persisted, component override saved,
  reset inherited General without removing unrelated preferences.
- `bun tools/verify-compositor-glass.ts`: native presentation and idle frame check
  passed (`idleFrames=1`).
- `bun tools/verify-inner-shadow.ts`: 15,411 changed edge pixels all became brighter
  with shadow zero; the core had zero changed pixels. The backdrop boundary still
  refracts with the same optical parameters. Moving Preferences twice left zero
  detached-material pixels in the output-origin test area.
- Synthetic screenshots in `/tmp/tahow-inner-proof/` were inspected, including
  `shadow-off.png` and `settings-position.png`.

Only synthetic content was captured. No passwords, real-session locking or
unlocking, niri, HDR, Vulkan, rotation or fractional-scale validation is claimed.

Final checks passed: `bun run check` (143 QML files), `bun test` (52 passed),
widget generated-output consistency, native localized damage (2,450 changed
refracted pixels, zero clip leaks), clipping/transform/reparenting checks,
2,000 protocol updates with region-budget enforcement, Settings/palette native
presentation, and four plugin unload/load operations in the isolated compositor.

The validated native library replaced the repository's local build through an
unload/load cycle; the previous library and preferences were backed up under
`/tmp/tahow-before-inner/`. The shell was exported to a temporary local catalogue,
installed through Ryostore and reloaded. Installed `GlassSettings.qml` and
`CompositorGlass.qml` hashes match source. Existing preference values were
preserved. Final main-session IPC reported `compositor-live`, ready material,
island and surface opacity 1, and no retained snapshot. The desktop widget
packages were regenerated in source; this update did not reinstall independent
widget products or publish the catalogue.
