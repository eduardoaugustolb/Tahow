# Live compositor glass verification — 2026-11-18

## Result

Tahow now has an optional Hyprland compositor provider for real-scene glass.
It inserts the native acrylic material immediately before the requesting
Wayland surface in the render pass. The material samples the scene already
composited below that surface; the QML bridge sends geometry and optical
parameters over a local socket, not pixels.

The island, command palette, Preferences sidebar and independent Ryoku widgets
have source integrations. A native material is reported as ready only after a
material draw has been submitted. The island and palette can start without a
frozen screen-capture buffer when the native provider is available. Widgets no
longer use a wallpaper texture as a substitute for live underlay glass. When
the provider arrives after island startup, all currently visible Glass consumers
must have ready native replacements before release of the old snapshot, its Host
reference and intermediate FBO. This reactive gate covers dynamic children,
visibility, inherited opacity and overflow; a visible sibling still needing the
QML fallback keeps the snapshot alive. No release timer is used.

The implementation and tests were exercised in a separate, nested compositor.
The user's main compositor and installed shell were not modified or reloaded.
No commit, push, catalogue publication or permanent installation is recorded by
this verification report.

## Environment

- Hyprland 0.57.2, commit `11cbc6c577b84ffb1edf4df3fc5b6128c3ae6947`.
- OpenGL backend; AMD Ryzen 5 5625U / Barcelo integrated Radeon.
- Host display: 1920 × 1080, scale 1, unrotated.
- Matching installed Hyprland development headers; C++26 build.
- Synthetic test application content, isolated preferences, no authentication
  or real session-unlock automation.

The plugin checks the exact compositor commit and refuses an incompatible ABI.
Rebuild after Hyprland updates. See [build and activation instructions](../native/live-glass/README.md).

## Checks and observed results

Final acceptance was repeated against the corrected code. The final runner logs
are `/tmp/tahow-final-*.log`. The runner explicitly rejects non-bindable and
non-notifiable warnings; none were found.

| Check | Observed result |
| --- | --- |
| Native plugin build after cleanup hardening | Clean C++26 build at `/tmp/tahow-review-native-cleanup-build/tahow-live-glass.so`. |
| `bun run check` | 143 QML files passed syntax validation; generated translations were current. |
| `bun test` | 52 tests passed, 0 failed. |
| `bun tools/build-widgets.ts --check` | Generated widgets matched canonical source and hashes. |
| `bun tools/verify-compositor-glass.ts` in the nested compositor | `NATIVE_GLASS_MOVED`; `NATIVE_GLASS_OK idleFrames=1`. |
| `bun tools/verify-pill-glass.ts --native` in the nested compositor | 14 island states, 420 sampled frames; native material remained ready, the overlay remained visible, capture ownership was released and no frozen capture content was retained. |
| `bun tools/verify-pill-glass.ts --wayland` without the plugin | Snapshot fallback passed the same 14 states and 420 samples. |
| `bun tools/verify-compositor-surfaces.ts` in the nested compositor | `SETTINGS_NATIVE_OK`; `PALETTE_NATIVE_OK noCapture=true`. |
| `bun tools/verify-native-glass-protocol.ts` in the nested compositor | 2,000 geometry updates retained one region rather than accumulating history; the 32-region per-peer budget held; 0 regions remained after removal; malformed/unsupported requests were rejected. |
| `bun tools/verify-compositor-clipping.ts` | `COMPOSITOR_GEOMETRY_OK clip=8px transforms=Translate,Scale,origin emptyClip=removed rotation=fallback ancestry=refreshed`; stdout and stderr were checked for non-bindable/non-notifiable warnings. |
| `bun tools/verify-native-damage.ts` after native review fixes | `NATIVE_DAMAGE_OK refractedPixelsChanged=1758 clipLeaks=0`; an outside-lens source change updated refracted pixels inside the lens, with an 80-pixel native clip and no leakage. |
| Capture-disabled island fallback | 14 states, 420 samples passed. |
| Snapshot-consumer gate, isolated offscreen check | `SNAPSHOT_CONSUMERS_OK siblingReady,dynamicChild,visibility,opacity,overflow`. |
| Nested-compositor unload/load smoke after cleanup fix | Four consecutive operations returned `ok`; the localized-damage test still passed afterward. |

The moving-content fixture uses a real application window below a transparent
layer. After the application stopped changing, the material counter advanced by
one settling frame during the test interval. This is evidence that the tested
static scene does not keep a continuous render loop running; it is not a GPU
utilization or power measurement.

The synthetic comparison at `/tmp/tahow-native-0.png` was visually inspected.
It showed correctly positioned glass, edge refraction and one copy of the
foreground label. An earlier coordinate error was corrected before this result.
No screenshot of private application content is needed for these checks.
The local-damage regression also saved synthetic before/after evidence in
`/tmp/tahow-native-damage-proof/`. Its source change affects only a small
rectangle outside the lens; 1,758 pixels inside the refraction region changed,
and the separate native clip showed zero leaked pixels. This verifies actual
local-damage propagation after the review fix rather than relying solely on
whole-window damage.

## Memory and scheduling

The native provider takes reusable work buffers from Hyprland's scene-resource
pool. The QML side holds no per-widget monitor-sized wallpaper texture and no
history of captured background frames. Geometry changes are coalesced over a
persistent local socket. Updates to content below the surface are handled by
the compositor's damage-driven rendering, without a QML screen-capture loop or
a process launch per frame. The bridge tracks ancestor clips, Translate, Scale
and transform-origin changes, including ancestor reparenting; fully clipped
regions are removed and disconnected. Transform-list references are read only
in imperative callbacks, with a refreshed ancestry cache. Geometry bindings read
notifiable properties on those objects instead of the non-bindable transform list.
Unsupported rotation and matrix transforms retain the QML fallback. Native
regions and their separate clips follow the actual surface-pass geometry, alpha
and fade rather than only the client's target geometry.

Refraction's maximum 49-pixel sampling footprint is included in real damage
propagation as well as region bounds. The additional expansion is scoped to
passes containing native glass. This conservative implementation can expand
damage for other blur operations in the same pass, increasing redraw work
without changing their visual parameters. It is not a claim of the mathematically
smallest possible damaged region.

The compositor's pooled buffers may still be monitor-sized. The tests do not
establish a total VRAM figure, an exact upper bound for all compositor pools,
a frame-time improvement or a power saving. The earlier roughly 75% estimate
for a reduced 4K intermediate texture applies to the snapshot fallback's
allocation calculation, not to measured native-provider VRAM savings.

Before plugin unload, native GlassPass instances are removed from all owning
render passes, so no queued pass can retain a virtual call into an unloaded
library. The final native cleanup build and repeated unload/load smoke passed
in the nested compositor; the main session remained untouched.

## Boundaries

- The source is the scene below the owning Wayland surface. Sibling UI elements
  already flattened into that same QML surface cannot refract one another.
- The native material uses rounded rectangles with a uniform radius. Its optical
  response differs from the previous QSB shader and is not claimed to match
  Apple's material exactly.
- Per-region refraction, bezel, dispersion and clarity do not change the global
  blur variant. Native blur pass count/size, brightness and color-management
  defaults remain compositor settings. The conservative damage expansion can
  increase work for other blur operations in the same render pass.
- The shell retains snapshot/simulated fallbacks when the provider is absent.
  Independent widgets fall back to simulated material, not wallpaper glass.
- Lockscreen authentication and its separate visual pipeline are untouched.
- Surface-pass movement/fade mapping is implemented, but compositor-animation
  visual timing was not independently validated.
- niri, Vulkan, HDR, fractional scaling, rotated displays and other GPU families
  were not validated. There are no GPU-time, FPS, VRAM or power benchmarks.

The unrelated TrayStrip change and its startup-verification script/fixture are
excluded from this delivery. Regeneration also synchronizes seven previously
stale widget-face copies with canonical source already present in HEAD; the
updated generated faces and manifest hashes are included together so packages
remain consistent with their source. This synchronization does not introduce
new canonical button or media-control behavior.
