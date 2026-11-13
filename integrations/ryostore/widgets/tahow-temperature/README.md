# Tahow Temperature

Available hardware temperature sensors.

Independent Ryoku desktopWidget plugin. No Tahow subshell is required. Simulated glass uses translucent gradients and rims, with no screen capture or optical refraction.

Reads pluginApi.pluginSettings with defaults. Settings and desktop placement are written by Ryoku's host; this plugin does not edit shared Tahow or host preferences. Right-click the tile to configure its material and available data options.

Commands: bun. Network: none. Privileged actions: none.
Reads available Linux /sys/class/hwmon and thermal sensors through the bundled Bun script.

Install locally with `ryoku plugin add /path/to/tahow-temperature --yes`. In Stage Editor, add or move the desktop widget; drag to position, resize with the host handles, and right-click for settings. The manifest requests host backing `none` so the Tahow face supplies its own material. Runtime size comes from the content's implicit dimensions; the host adds its placement padding.

Generated source: https://github.com/eduardoaugustolb/Tahow. Do not hand-edit generated files.
