# Independent widgets — verification 2026-11-12

Seven products were built from shared original Tahow sources with individual
service/content entry points, manifests and real preview captures. Installed
and enabled through `ryoku plugin add` and the host's `ryoku-plugins-place`
command. Placement is separate for every plugin; no host JSON was hand-edited.
The local Ryostore catalogue now lists all seven. Nothing was published.

Actual CPU, CPU temperature (k10temp Tctl), root filesystem space, available
memory and MPRIS title/art/position were observed in the Wayland preview on
Hyprland. Session and clock layouts were visually inspected. Source screenshot:
`/tmp/tahow-widgets-gallery.png`; independent PNG previews are kept with source.
The installed widgets were confirmed enabled in `ryoku plugin list --json`.
After the final shell reload, logs showed no widget QML or process errors.
A pre-existing host IPC setMotion type warning is unrelated.

The shell service does not include this user's mise Bun directory in PATH.
Temperature exposes a Bun executable setting, set through the host settings
command to the user's current Bun executable. Other machines can use `bun`
when available on PATH or choose its full path. Missing sensor data shows an
unavailable state. Media artwork accepts local URLs only; it makes no network
requests.

`bun run check` validates source and generated QML. `bun test` covers cumulative
CPU deltas, unavailable counters, MemAvailable accounting, CPU sensor selection,
local artwork, action allowlisting and all seven manifests. The actual session
face was tested with a fake service using `bun tools/verify-widget-interactions.ts`:
construction is inert; restart/shutdown wait for confirmation. No real session
lock, suspend, reboot, shutdown or authentication was automated.

All seven pass `ryoku plugin validate` with no blocking findings. Static warnings
remain: the SVG namespace www.w3.org is detected as a host although it is only
an SVG identifier; the shared service includes df/Bun branches that are disabled
in other widget kinds. Dependencies declare only commands actually used by each
kind. No validator bypass was used.

These cards use simulated glass rather than optical screen refraction. Public
PluginKit tokens provide the host accent. niri has not been validated.

## Python replacement and GitHub calendar

The original PythonFaceProvider was instantiated read-only to measure natural
face dimensions: usage cards 180×130, user 260×140, clock 156×120, media 340×120,
GitHub 540×180. Saved output-local scale/coordinates were read from widgets.json;
Tahow receives corresponding face dimensions and compensated host padding.
The Python faces were disabled through Config.setManyFor(), not a JSON edit.
The final Stage Editor view was inspected at /tmp/tahow-desktop-replaced.png.

GitHub uses the same public contributions API as Python, explicitly declared
in its network capabilities. No token is requested. The username is configured
through the host settings; year navigation, refresh and date hover are local UI.
Future dates have no visible cell or hover target. The date window uses min/max
weeks (defaults12/53), clamped to available width/height, retaining the most
recent date even when it has no contributions. Cell width equals cell height.
Rounded original-symbol controls replace native themed buttons.

A separate product-manifest.json includes the installed plugin manifest.json.
This was verified after a Ryostore update: all eight report desktopWidget hosts
and enabled state, and all are visible in Stage Editor. Final validation:
102 QML files, 34 passing unit tests, no real session actions exercised.

## Optional Liquid Glass variants

All eight plugins expose optional material variants. Optical material uses the
published Ryogami wallpaper, not whole-output capture. NativeGlass and its
attributed shader sources/QSB are packaged self-contained. A Wayland preview
was inspected at /tmp/tahow-liquid-variants-verified.png. A circular dependency
between implicit height and render scale was found and removed; natural sizes
are independent from their rendered height. The GitHub preview is kept separate
from the seven-widget gallery so its wider layout cannot overlap other tiles.

The QML interaction harness verifies legacy default material, the bare-clock
option, opt-in Liquid Glass and stable natural geometry without writing user
preferences. The actual update was verified with SHA-256 readbacks: plugins.json
and widgets.json were byte-identical before and after installing all eight
updated products. No material selection, placement or scale was overwritten.

## Suite grouping and customization

Each manifest now declares set:"Tahow Widgets", the installed Stage Editor's
supported suite-group field. The installed group was visually verified with
8/8 members. StageWidgetPage only embeds the built-in inspector for non-plugin
items, so Tahow adds its own hover gear and a fixed-size preferences window.
That window renders the actual installed manifest schema, including text fields
and variant choices, and sends only user-edited keys to ryoku-plugins-place.
It never writes configuration JSON directly or resets a plugin's settings.
The window stays instantiated when hidden so pending writes can finish.

The compact-clock option is opt-in (default false). At the user's request it
was enabled for the current clock only. Width now follows digit/date text plus
6 logical pixels on each side; existing height and position remain unchanged.
The before/after state comparison confirmed clockCompact was the only edited
setting. The full product update left plugins.json/widgets.json byte-identical
before that explicit clock adjustment. Stage verification screenshot:
/tmp/tahow-compact-clock.png. Unit suite:35 pass; QML syntax:129 files.
