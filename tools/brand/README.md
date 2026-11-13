# Tahow banner

Render the approved transparent Tahow logo and the bundled Sacramento font over
Tahow's original image-generated glass-orbit background. Text uses the reload
screen's existing refraction/silhouette shader; the logo uses the same periodic
silhouette field, preserving its original optical material. The background uses
the reload screen's flowing refraction shader. The loop is four seconds.

```sh
bun tools/build-shaders.ts
bun tools/animate-banner.ts
```

Requires Quickshell, Qt's OpenGL RHI backend and FFmpeg. This renders in an
isolated offscreen runtime, without loading the desktop or authentication code.
Outputs are `docs/brand/tahow-banner-v2.{png,gif,webp,mp4}`. The README uses GIF;
MP4 and WebP retain more faithful gradients. Font attribution and OFL text remain
in `shell/reload/fonts/`; input provenance is recorded beside the output.

Verified on 2026-11-13: offscreen QML/shader rendering, visual PNG inspection,
full GIF decoding with FFmpeg (80 frames, 960 × 352, four seconds),
`bun run check`, and `bun test` (49 passed). No desktop installation is changed.
