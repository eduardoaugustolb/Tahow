# Independent Tahow desktop widgets

Eight Ryoku desktopWidget plugins: CPU, temperature, disk, memory, session,
clock, media and GitHub contributions. Each has its own ID, settings, service, placement, and
lifecycle. They do not require the Tahow subshell or Python shell to be active.

The Python shell's usage cards, user face, digital clock and music face were
read as functional and layout references. These implementations use original
Tahow QML with the same geometric symbols and neutral/accent material policy
as the shell. They import only public PluginKit and Quickshell APIs.

Desktop cards use simulated glass: translucent gradients, rounded corners,
rim and shadow. They do not continuously capture the screen or pretend to
refract moving desktop windows. Right-click a widget for its material,
appearance, refresh interval and applicable clock/temperature settings.

Build the eight self-contained plugin folders:

```sh
bun tools/sync-i18n.ts
bun tools/build-widgets.ts
```

Generated products live in `integrations/ryostore/widgets/tahow-*`. Install
with `ryoku plugin add /absolute/path/to/tahow-cpu --yes` (repeat for each
wanted widget). Add, move and resize each in Ryoku's Stage Editor / desktop
widget interface. The host owns placement and settings persistence.

Preview actual data without installing:

```sh
qs -p integrations/widgets/Preview.qml
```

The preview saves individual real widget captures under `assets/` after data
sampling. These PNGs are catalogue previews, not fixture values. Source data
comes from Linux procfs, filesystem statistics, readable hwmon/thermal sensors,
and MPRIS. No temperature sensor yields an explicit unavailable state. Media
art is limited to local URLs, avoiding implicit network fetches.

Session actions run only after explicit interaction. Suspend, restart and
shutdown require a second click within a short confirmation window. Tests use
a fake service and never suspend, restart, shut down or unlock a real session.

GitHub settings include username, minimum weeks (12) and maximum weeks (53). The window always ends at the latest eligible date, including empty days; future days are hidden. Cells retain a square aspect ratio. Public contributions are requested from github-contributions-api.jogruber.de, the provider used by the Python reference. No token is requested.

Catalogue export: `bun tools/export-widgets.ts --to /path/to/ryostore`. Plugin metadata is manifest.json; the separate product-manifest.json distributes that file along with the plugin sources.

## Material variants and compatibility

Right-click any widget and choose Material: `simulated`, `liquid`, or `none`.
Liquid Glass uses the attributed Ryoku optical shader over the wallpaper
published by Ryogami, with adjustable bevel, depth, index, RGB dispersion and
frost. It does not capture the screen or track application windows. With no
wallpaper texture available it retains the simulated material fallback.
The clock also offers a `bare` style that removes its card, rim and shadow.

New settings are read with defaults; rendering does not write preferences or
change geometry. Existing instances remain simulated unless explicitly changed.
Product updates preserve host-owned positions, scale and settings. The GitHub
calendar distributes its horizontal spacing evenly while retaining square days.
