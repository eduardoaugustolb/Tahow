# Pill hover capture

Environment: live Hyprland v0.57.2 reported by `ryoku wm status`; Bun 1.4.4.

The hover timer previously requested desktop capture even for workspace, OSD,
device and notification modes, which have no hover preview. Capture fades the
island out before acquiring the background, producing a blink.

Hover now changes preview state directly, only for supported modes. Previews
use simulated glass, avoiding both capture latency and self-capture. Explicit
expansion still uses the existing capture preparation. Notification action
hover handling is preserved.

Validation: `bun run check` passed (133 QML files); `bun test` passed (40 tests).
Visual verification of the running shell was not performed and the installed
shell was not replaced or reloaded. niri was not tested.
