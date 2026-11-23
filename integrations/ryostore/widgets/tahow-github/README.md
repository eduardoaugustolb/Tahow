# Tahow GitHub

Public GitHub contribution calendar with year navigation.

Independent Ryoku desktopWidget plugin. No Tahow subshell is required. Material variants: simulated glass, live compositor Liquid Glass, prismatic glass, and no background. Liquid and prismatic glass require the optional matching Tahow Hyprland compositor plugin. They refract the real scene below the widget without wallpaper snapshots or screen capture and fall back to simulated glass when the provider is unavailable. Existing settings remain unchanged, and simulated glass remains the default.

Reads pluginApi.pluginSettings with defaults. Settings and desktop placement are written by Ryoku's host; this plugin does not edit shared Tahow or host preferences. Right-click the tile to configure its material and available data options.

Commands: none. Network: github-contributions-api.jogruber.de (public contributions). Privileged actions: none.


Install locally with `ryoku plugin add /path/to/tahow-github --yes`. In Stage Editor, add or move the desktop widget; drag to position, resize with the host handles, and right-click for settings. The manifest requests host backing `none` so the Tahow face supplies its own material. Runtime size comes from the content's implicit dimensions; the host adds its placement padding.

Generated source: https://github.com/eduardoaugustolb/Tahow. Do not hand-edit generated files.
