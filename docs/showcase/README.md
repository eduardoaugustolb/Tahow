# Showcase captures

Refreshed on 2026-11-13 on Ryoku/Hyprland v0.57.2, Quickshell 0.3.2,
1920 × 1080 at scale 1, current desktop accent and pt-BR UI. Full screenshots
retain their original resolution and use WebP quality 88. Media detail crops
use quality 90. Clicking documentation images opens their original size.

## Live desktop captures

The collapsed island, expanded home/media/controls/timer, command palette and
seven preference pages were captured from the installed shell. Spotify was
playing: artwork, metadata, position and controls come from MPRIS. Playback was
not changed by the capture tools; natural track changes occurred between shots.
The pill detail and individual media widget are crops of the new collapsed
island capture. Their artwork confirms that the installed media widget accepts
Spotify HTTPS covers and uses actual rounded image clipping.

`bun tools/capture-showcase.ts` captures into a temporary output directory,
using an empty workspace and restoring the original workspace afterward. It
refuses a capture workspace containing application windows. Inspect every
capture before publishing; user activity may change focus during a capture.
The first home capture was discarded because an application window appeared;
the replacement shows the clean desktop and live media card.

## Isolated source previews

`bun tools/render-showcase-previews.ts` produces the eight-widget gallery,
hover media preview, notification-center preview and lockscreen preview.
These are source-component renders, not screenshots of those installed layouts.
Preview processes use a copied preference store with pt-BR selected and
notification-server takeover disabled; they cannot change user preferences.
The gallery uses real system metrics, public GitHub contributions and MPRIS
playback. Its temporary layout does not alter installed widget placement.

Notification text is a local demonstration fixture, never the user's message
history. LockView uses a simulated authentication object whose login method
throws; no actual session lock/unlock or password entry is automated. The
password field remains empty. This does not validate PAM or fingerprint login.

Offscreen preview logs include shutdown-time property-binding warnings and a
ColorQuantizer warning for remote art: all published frames were inspected;
the Image components display album art. The warning is not claimed fixed by
the widget artwork change. Native niri behavior was not tested.

## Provenance and publication

The desktop owner's current wallpaper appears only within requested captures;
the original wallpaper file is not bundled. Its authorship/license has not been
established here. Album covers and application icons belong to their respective
owners. The project license covers its software, not third-party artwork shown
inside interface screenshots. Capture tools do not send these assets elsewhere
except through the user-requested documentation publication.

`bun tools/sync-showcase.ts` copies reviewed repository media to the website.
Both language sections link the same assets and label previews and limitations.

## Animated reload cover

The existing reload-cover WebP and MP4 remain rendered from
`shell/reload/Welcome.qml`, rather than desktop captures. They use the original
image-generated glass-orbit background and the OFL Sacramento font. Provenance:
`shell/reload/assets/tahow-glass-orbit.provenance.json`; font notice:
`shell/reload/fonts/OFL.txt`. These existing animations were not changed during
the screenshot refresh. See [reload-cover notes](../reload-cover.md).
