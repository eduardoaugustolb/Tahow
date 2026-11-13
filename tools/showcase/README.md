# Refreshing the showcase

Keep an MPRIS player playing before capture. The live capture tool uses the
installed shell's IPC and the focused Hyprland output. It chooses workspace 9
(or TAHOW_CAPTURE_WORKSPACE), refuses a workspace with application windows,
closes only Tahow surfaces it opens and restores the original workspace.

```sh
bun tools/capture-showcase.ts /tmp/tahow-showcase-refresh
bun tools/render-showcase-previews.ts /tmp/tahow-showcase-refresh
```

Inspect every frame before copying to docs/showcase. Other user activity can
change focus while capturing. Live captures use grim; previews use source QML
components and grabToImage in an offscreen OpenGL RHI instance. The preview
runner uses a copied preference store and disables notification-server ownership.
Media data and metrics are live; notifications are fixtures; authentication is
simulated and the login function throws. Never load the real lock runtime.

After converting reviewed PNGs to WebP (quality 88, original resolution), sync
and validate:

```sh
bun tools/sync-showcase.ts
bun run docs:build
bun run check
bun test
```

Document actual environment, capture/preview distinctions and third-party
artwork provenance in docs/showcase/README.md. No niri validation is implied.
