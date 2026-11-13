# Animated wallpaper reload cover

The fixed Tahow background is `shell/reload/assets/tahow-glass-orbit.png`, an
original image generated with the built-in image_gen tool. Its clear rounded
glass contours echo the floating island and command palette, with icy blue and
cobalt refraction. The full generation prompt and provenance are stored beside
the image in `tahow-glass-orbit.provenance.json`.

Render the fixed background with the animated Sacramento lettering:

```sh
bun shell/bin/reload-cover.ts --fixed --out /tmp/tahow-welcome.mp4
```

`Welcome.qml` also defaults to this bundled fixed background. The optional
wallpaper-following mode below remains available when explicitly requested.

Tahow can render a cursive `welcome` lens over a wallpaper into a 1920×1080,
24 fps, four-second H.264 loop. The shader samples the wallpaper inside the
letter mask with refraction, chromatic separation, edge reflections and a moving
highlight. Motion is periodic: a spatial flow field deforms the background glass
and its caustic lighting, while a separate traveling field reshapes the joined
letter contours and their optical normals. The word has no vertical bobbing.
This is an original
procedural treatment of the visual reference, with no Apple assets included.
The connected script is Sacramento by Brian J. Bonislawsky (Astigmatic), bundled
under the SIL Open Font License in `shell/reload/fonts/`. It approximates the
reference's connected handwriting; it is not Apple's proprietary lettering.

Generate a file:

```sh
bun shell/bin/reload-cover.ts /path/to/wallpaper.webp --out /tmp/welcome.mp4
```

Follow wallpaper changes:

```sh
bun shell/bin/reload-cover.ts --watch /tmp/welcome.mp4
```

The System page in Tahow Settings also exposes **Generate glass reload cover
from wallpaper**. It is off by default. With the Ryoku adapter active and this
option enabled, a Bun worker subscribes
to `ryogami.sock` and writes `~/.cache/tahow-shell/reload-cover.mp4` (respecting
`XDG_CACHE_HOME`). Ryogami supplies its current default wallpaper on subscription;
if there is no default, the first output is used. One shared cover is generated,
not a different movie per monitor. Connection loss retries after two seconds.

The worker debounces changes for 1.5 seconds, throttles generation starts to
once every 30 seconds, keeps only the latest pending wallpaper, and serializes
rendering. Identical image contents are skipped. Successful output replaces the
previous movie atomically, so failures leave the previous cover available.
Static PNG/JPEG/WebP/BMP images up to 100 MiB are supported. Animated wallpaper
inputs and video backgrounds are not supported. Dependencies: Bun, Quickshell,
working Qt OpenGL rendering and FFmpeg with libx264. The font is bundled.

## Ryoku publication boundary

In the Ryoku Hub's reload-cover section, **Add asset…** imports a copy of the
video. That copy does **not** follow subsequent changes to the generated file.
The current `ryoku-hub reload-cover` API exposes `import` and `prune`, but no
activation command or externally managed dynamic asset binding. Therefore this
implementation automatically regenerates the file, but does not automatically
replace the active Ryoku cover. A host API supporting a stable external file
or transactional activation is needed to finish that integration. Tahow does
not rewrite `brand.json`, overwrite managed asset copies, or patch installed
Ryoku files to bypass this boundary.

## Verification — 2026-11-13

`bun run check` and `bun test`: passed (40 tests). The queue tests exercise
burst coalescing, serialization, throttling, and recovery after failure.
The scene was rendered headlessly using Qt's OpenGL RHI and inspected with the
local wallpaper; the default offscreen software backend cannot render shaders.
Vulkan offscreen initialization is unsupported on this setup. The OpenGL
render needed execution outside the restricted sandbox. No real shell reload,
authentication, installed-desktop changes, or niri validation was performed.

### Approved application

After user approval on 2026-11-13, the 1,562,593-byte animated fixed-background
movie was imported with `ryoku-hub reload-cover import` and activated using the
installed Hub component's own `edit("reloadCover", descriptor)` and `save()`
functions. Only the `reloadCover` brand field changed; the managed movie's
SHA-256 matches the approved preview. No shell reload was triggered.
The 96-frame loop uses periodic spatial deformation with no vertical word
translation. The encoded last-to-first frame RMSE was 0.01843, compared with
0.01628 and 0.01692 for adjacent frames near the seam, consistent with continuous
motion rather than a reset jump. This does not validate niri or a real reload.

Before pushing, the staged cover/showcase changes were exported to an isolated
checkout and passed `bun run check` and all 38 tests there. The earlier 40-test
workspace run also included two pre-existing login integration tests that are
outside this commit.
