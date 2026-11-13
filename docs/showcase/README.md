# Showcase captures

Captured on 2026-11-13 from the Tahow source checkout, on Ryoku with Hyprland (Wayland), a 1920 × 1080 output at scale 1, and Quickshell. The interface uses the current desktop accent, dark appearance and pt-BR locale. Images are WebP at quality 88, with their original resolution retained.

The main shell surfaces use the real desktop background and the existing desktop widgets. The eight-widget gallery uses a temporary layout of the source WidgetFace and WidgetService components, with Liquid Glass and the current wallpaper behind them. Metrics and GitHub contributions come from runtime services. No media player was active and the notification center was empty. These captures document appearance, not every interaction or host capability.

The lockscreen uses the source LockView and GlassClock in an ordinary preview surface, with a simulated authentication object and an empty password field. No real session was locked, no authentication was attempted, and no password or keystroke was captured. It is not evidence of PAM or fingerprint validation. Existing source edits to GlassClock were included without modification.

Wallpaper provenance: the desktop owner's existing wallpaper, named wallhaven-x866ko.webp. It appears only as part of the requested desktop screenshots; the original image is not bundled. Artwork authorship and license have not been established here. The project's AGPL license covers its software and does not grant rights to the wallpaper or third-party application icons visible in captures.

Temporary preview processes were closed and the original workspace was restored after capture. Installed desktop files and user preferences were not edited. niri was not tested.

## Animated reload cover

`reload-cover.webp` is a 960-pixel-wide, 12 fps animated preview; the linked
`reload-cover.mp4` is the approved 1920 × 1080, 24 fps, four-second H.264 loop.
Both are rendered from `shell/reload/Welcome.qml`, not desktop captures.
The background and connected Sacramento glyph contours deform continuously,
with periodic optical flow, refraction and highlights; the word does not bob.

The fixed wallpaper was generated specifically for Tahow using the built-in
image_gen tool, inspired by the island and command palette's rounded glass
surfaces. Its prompt and provenance are in
`shell/reload/assets/tahow-glass-orbit.provenance.json`. Sacramento is bundled
under the SIL Open Font License; see `shell/reload/fonts/OFL.txt`.

After approval, this movie was activated through the Ryoku Hub. That application
is separate from the earlier screenshot session described above. The encoded
loop seam was compared with neighboring frames; no real shell reload or niri
runtime test was performed. See [reload-cover notes](../reload-cover.md).
