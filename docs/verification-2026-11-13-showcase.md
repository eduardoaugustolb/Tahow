# Showcase refresh and media widget artwork

Environment: Hyprland v0.57.2, Quickshell 0.3.2, 1920 × 1080 at scale 1.
Spotify provided real MPRIS playback, artwork and positions. No playback actions
were automated. Preview captures used offscreen OpenGL RHI and copied settings.
No real authentication or niri validation was performed.

The widget's artwork policy previously stripped all remote URLs, although
Spotify advertises HTTPS CDN images and the pill already displayed them.
The shared helper now permits HTTPS artwork plus existing local/qrc images,
rejecting HTTP, executable/data schemes, protocol-relative URLs and embedded
credentials. The media manifest explicitly declares player-selected artwork
network access. Image fallback follows actual load status. ClippingRectangle
provides real rounded clipping, unlike Rectangle.clip, which clipped to the
rectangular item bounds. Generated widget exports were rebuilt and inspected.

Exported the catalogue using tools/export-widgets.ts, refreshed Ryostore's
catalogue and reinstalled tahow-media through Ryostore. Reloaded the shell.
The new live desktop capture confirms album artwork and rounded clipping.
User preferences and installed widget positions were not edited.

Recaptured every existing still in the showcase, plus media-pill, hover-preview
and media-widget details. The initial home capture contained an application
window and was discarded before publication; its replacement was inspected.
Gallery widgets, lockscreen, notifications and hover preview are source renders
and are labeled accordingly. Notification fixtures contain no personal history;
the fake authentication login method throws. Full capture provenance is in
showcase/README.md.

Added English and Portuguese showcase pages, sidebar navigation and overview
links. Image captions distinguish live captures from source previews. Image
links open originals; reviewed media is mirrored by tools/sync-showcase.ts.

Validation:
- bun run check: passed, 133 QML files and generated translations.
- bun test: 50 passed, including HTTPS/unsafe URL regression cases and regenerated product manifests.
- bun tools/verify-widget-interactions.ts: passed with a fake service.
- bun run docs:build: passed, 15 static pages including both showcase routes.
- Visually inspected the refreshed captures, gallery and isolated previews.
  CUA's browser access host was unavailable; browser layout is not claimed as visually tested.
