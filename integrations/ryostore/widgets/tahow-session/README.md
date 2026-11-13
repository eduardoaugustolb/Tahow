# Tahow Session

Explicit lock, suspend and session actions.

Independent Ryoku desktopWidget plugin. No Tahow subshell is required. Material variants: simulated glass, Liquid Glass refracting the published wallpaper, and no background. Liquid Glass does not capture the desktop or track windows; it falls back to simulated glass when no wallpaper is available. Existing settings remain unchanged, and simulated glass remains the default.

Reads pluginApi.pluginSettings with defaults. Settings and desktop placement are written by Ryoku's host; this plugin does not edit shared Tahow or host preferences. Right-click the tile to configure its material and available data options.

Commands: ryoku-shell. Network: none. Privileged actions: none. Session actions run only after explicit clicks.


Install locally with `ryoku plugin add /path/to/tahow-session --yes`. In Stage Editor, add or move the desktop widget; drag to position, resize with the host handles, and right-click for settings. The manifest requests host backing `none` so the Tahow face supplies its own material. Runtime size comes from the content's implicit dimensions; the host adds its placement padding.

Generated source: https://github.com/eduardoaugustolb/Tahow. Do not hand-edit generated files.
