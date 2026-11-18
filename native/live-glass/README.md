# Tahow live compositor glass

This Hyprland plugin renders the native acrylic material immediately before the
requesting layer (or Tahow Preferences window) in the render pass. The source is
the GPU framebuffer containing the scene below that surface. No wallpaper,
screencopy, screenshot files, CPU readback, DMA-BUF export/import or per-frame
process launch is involved.

## Build

Requires the running Hyprland's development headers, pkg-config, a C++26 compiler
and nlohmann/json headers. The plugin checks the exact Hyprland commit hash and
requires the OpenGL backend. Rebuild after compositor updates.

From the Tahow repository:

```sh
bun native/live-glass/build.ts
```

Output: native/live-glass/build/tahow-live-glass.so (ignored by Git).
The optional output-directory argument keeps build artifacts outside the checkout.

## Enable

Build and test in a nested Hyprland first. Load the resulting absolute path using
Hyprland's plugin manager, or on Ryoku through Hub > Plugins / its compositor
plugin management command. No script in this directory changes desktop config,
installs a plugin or reloads the user's shell automatically.

For an explicit temporary manual test in the intended compositor:

```sh
hyprctl plugin load /absolute/path/tahow-live-glass.so
# rollback
hyprctl plugin unload /absolute/path/tahow-live-glass.so
```

Run the modified Tahow sources (or package them through the normal export flow).
The QML bridge discovers the plugin automatically. Diagnostics report
`compositor-live` only after the compositor has actually submitted the material.
The existing screenCapture preference also gates this native underlay capability;
turning it off disables real-scene glass. It does not mean pixels are sent to a
capture client when this provider is active.

## Scheduling and memory

Geometry changes are coalesced with Qt.callLater over a persistent local socket.
Moving content below does not require QML updates: Hyprland's damage-driven pass
re-evaluates the material in the same frame as the underlying scene. Unchanged
geometry sends no messages. Hidden ordinary elements disconnect; only startup
presentation probes keep discovery active while hidden. Disconnect/remove damages
the old bounds and revokes the region. Fully clipped elements remove their region
and disconnect. The bridge tracks ancestor clipping plus Translate, Scale and
transform-origin changes, including an ancestor being reparented. Transform-list
references are refreshed outside QML bindings; bindings read the transform objects'
notifiable properties, avoiding non-bindable/non-notifiable warning floods. Unsupported rotation and matrix transforms select the
QML fallback rather than drawing an axis-aligned native substitute.

The native region and its clip are mapped to the actual surface-pass geometry,
alpha and fade, so compositor-driven movement and fades affect both the material
and its owning surface. If the plugin becomes available after startup, the island
releases its saved capture and intermediate FBO only after every currently visible
Glass consumer has a ready native replacement. The gate is reactive, includes
dynamic children and inherited opacity/visibility, and preserves the snapshot
while any visible sibling still needs it. No release timer is used.

The native Dual Kawase/acrylic provider obtains reusable work buffers from the
compositor's scene-resource pool. There is no growing history of background images
and no per-widget monitor-sized QML texture. These shared work buffers can still
be monitor-sized; this is not a claim of zero GPU memory or a cropped allocation.
The maximum 49-pixel refraction footprint participates in both region bounds
and actual damage propagation. An additional damage-expansion hook is active only
while a render pass containing native glass is being rendered. It conservatively
adds that footprint to blur damage expansion throughout that pass, so other blur
operations in the same pass can redraw a larger area. It does not change their
optical settings. Actual blur cost still depends on damaged area, region area and
compositor blur passes.

Each peer is checked against the same Unix UID and the actual Wayland surface
process PID. Only explicitly supported surface namespaces can be targeted. The
socket lives inside the compositor instance directory and has mode 0600; requests,
clients and regions have fixed bounds. No pixel content is readable through it.

## Scope and limitations

- Island, its Glass surfaces, command palette, independent ryoku-widgets, and
  Tahow Preferences sidebar use the provider. Lockscreen authentication and its
  own visual pipeline are untouched.
- The underlay is the scene below the owning Wayland surface. Two UI elements
  inside the same QML surface cannot refract each other's already-flattened UI.
- Rounded rectangular shapes use a uniform radius. Native optics differ from
  the old QSB shader. Refraction depth, bezel, dispersion and clarity are mapped
  per region without changing the global blur variant or other applications'
  optical settings. The pass-scoped conservative damage expansion can still
  increase their rendering work.
  Blur pass count/size, brightness and color-management defaults remain shared
  with the compositor. No claim of exact Apple material equivalence is made.
- Plugin absence falls back to the existing snapshot/simulated shell material;
  widgets use simulated material, never a wallpaper stand-in for live glass.
- Only Hyprland 0.57.2 / OpenGL on AMD Barcelo, unrotated scale-1 output, was
  exercised. niri, Vulkan, HDR, rotation and fractional scale are unvalidated.
  Surface-pass animation mapping is implemented, but compositor-animation visual
  timing has not been independently validated.

## Verification

Inside an isolated Hyprland with the matching plugin loaded:

```sh
bun tools/verify-compositor-glass.ts
bun tools/verify-pill-glass.ts --native
bun tools/verify-compositor-surfaces.ts
bun tools/verify-native-glass-protocol.ts
bun tools/verify-compositor-clipping.ts
bun tools/verify-native-damage.ts
```

The first test places a synthetic application window below a transparent layer,
changes the application content, requires a presented native material, and checks
that rendering settles after damage stops. The second exercises 14 island states
and 420 samples with no screen-capture buffer or material disappearance.
The remaining checks cover Preferences/palette presentation and bounded protocol
state under repeated updates and removal. The clipping check covers an 8-pixel
ancestor clip, Translate/Scale/origin notifications, ancestor reparenting, fully clipped region removal
and fallback for unsupported rotation. The local-damage regression changes only
a small application rectangle outside the lens, requires changed refracted pixels
inside it, and checks that a separate native clip has no pixel leakage.

The [2026-11-18 verification report](../../docs/verification-2026-11-18-compositor-glass.md)
records final acceptance results and unvalidated platforms. The final acceptance
run passed QML/generated-file checks, 52 tests, native/fallback transition tests,
clipping/reparenting, local damage, bounded protocol state and native surfaces.
The runner explicitly rejects non-bindable/non-notifiable geometry warnings. The plugin was loaded
only in the nested test compositor; the main session was not changed. No GPU-time,
VRAM, FPS or power benchmark has been performed.

Plugin unload removes native GlassPass instances from every owning render pass
before the shared library can be closed. The nested-compositor unload/load smoke
passed four consecutive operations after this cleanup fix.

## Attribution

Tahow bridge/plugin code: AGPL-3.0-only. Uses Hyprland's public plugin headers,
render-pass hook API, and native Dual Kawase/acrylic provider, copyright Hyprland
contributors, BSD-3-Clause. No shader code or proprietary Apple assets are copied.
References: https://github.com/hyprwm/Hyprland and
https://wiki.hypr.land/hyprland-plugins/using-plugins/ .
