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
